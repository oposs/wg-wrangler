# repo-infra: container v5
#
# Purpose: Autotools as a container driver (D18).
# Choose: The build needs a container (D16).
# Supplies: A Containerfile and the CONTAINER_DRIVER conditional in
#   configure.ac.
# Pieces: container-m4
#
# Autotools as a container driver (D18).
#
# Outside the container this file is the whole build: `make` builds the image,
# and every other target runs in it. Inside the container -- where configure ran
# with --disable-container -- the CONTAINER_DRIVER conditional is false and this
# file defines nothing at all, so the project's own targets stand.
#
# repo-infra owns this file. The project owns its Containerfile and what goes in
# it. Include it from Makefile.am, after calling REPO_INFRA_CONTAINER in
# configure.ac:
#
#     include $(top_srcdir)/build/container.mk
#
# The project may set, before the include:
#
#   CONTAINER_TAG     tag to build and run              (default: $(PACKAGE)-build:local)
#   TEST_DEV_MOUNTS   dirs holding interpreted source   (default: none)
#
# There is deliberately no way to declare host packages. Needing one is what
# sent this project to containers in the first place (D16).
#
# In driver mode, every `make` invocation prints GNU Make warnings like:
#
#     Makefile:NNN: warning: overriding recipe for target 'dist'
#     Makefile:NNN: warning: ignoring old recipe for target 'dist'
#
# They name `dist` and `check-am`, and `check-recursive` too in a project with
# SUBDIRS. Not `install`: automake's generated `install:` is prerequisite-only
# and carries no recipe body of its own, so there is no old recipe for this
# fragment's `install:` to override. These lines come from GNU Make itself
# parsing the generated Makefile -- not from automake, so
# `AUTOMAKE_OPTIONS = -Wno-override` does not silence them and must not be
# added. They are the expected sound of this fragment replacing automake's own
# recipes; they are not a sign anything is broken.

if CONTAINER_DRIVER

CONTAINER_TAG ?= $(PACKAGE)-build:local
TEST_DEV_MOUNTS ?=
TARGET ?=

.PHONY: container container-base check-am check-recursive test-dev

# The full image. Its build phase runs ./configure --disable-container && make
# && make install, so building the image IS building the project. Always runs:
# podman's layer cache makes a no-change rebuild cheap, and `make check` must
# never test a stale image.
container:
	$(DOCKER) build -t $(CONTAINER_TAG) -f $(top_srcdir)/Containerfile $(top_srcdir)

# Same image, narrower prerequisite: rebuild only when the container definition
# changes. This is what the dev loop hangs off, so editing a script rebuilds
# nothing.
container-base: .stamp-container-base
.stamp-container-base: $(top_srcdir)/Containerfile
	$(DOCKER) build -t $(CONTAINER_TAG) -f $(top_srcdir)/Containerfile $(top_srcdir)
	touch $@

all-local: container

# The seam (D15). Inside the image `make check` is the project's own native
# test target. Automake's `check:` has no recipe of its own: it depends on
# check-am, or on check-recursive when the project has SUBDIRS, and those run
# the suite. A rule of ours named `check` would only add to that, so the suite
# would run on the host first. Replacing both recipes, as `dist` below does,
# leaves the container as the only place the tests run.
check-am check-recursive: container
	$(DOCKER) run --rm $(CONTAINER_TAG) make -C /src check

# The dev loop: one test file, run against the live working tree. Never used by
# CI -- what CI must verify is that the image builds and its contents pass,
# which is `make check`.
#
# The mounts are read-write, not :ro. The developer already owns the whole
# source tree, so a read-write mount of a directory they can edit anyway grants
# no capability they did not already have -- and automake's own test-driver
# writes <test>.log and <test>.trs next to each test file on every run, which a
# native `make check` already does to the same tree. A :ro mount was tried and
# fails outright: "Read-only file system" from test-driver itself.
#
# -i -t only when stdin is a terminal, where they let a debugger in the test
# talk to the developer. From a pipe, cron or CI the docker CLI refuses `run
# -it` with "cannot attach stdin to a TTY-enabled container because stdin is
# not a terminal", and podman warns "The input device is not a TTY". The same
# test is in container-make.mk.
test-dev: container-base
	@if [ -z "$(TARGET)" ]; then \
		echo "Error: TARGET is required"; \
		echo "Usage: make test-dev TARGET=t/foo.t"; \
		exit 1; \
	fi
	@if [ -z "$(TEST_DEV_MOUNTS)" ]; then \
		echo "Error: TEST_DEV_MOUNTS is not set"; \
		echo "Set it in Makefile.am, e.g. TEST_DEV_MOUNTS = lib t bin/plugins"; \
		exit 1; \
	fi
	tty=; if [ -t 0 ]; then tty="-i -t"; fi; \
	$(DOCKER) run --rm $$tty \
		$(foreach d,$(TEST_DEV_MOUNTS),-v $(abs_top_srcdir)/$(d):/src/$(d)) \
		$(CONTAINER_TAG) make -C /src check TESTS=$(TARGET)

# The tarball is built by the same toolchain every time. Building it on the host
# instead would let a host-built and an image-built tarball differ, and nobody
# would notice until a user unpacked the wrong one. Exactly one tarball is
# expected in /src afterwards (mirroring the same hazard and guard as
# release-build/release-source-tarball.yml): none means the build failed silently,
# more than one means a stale tarball is sitting next to the fresh one and
# nothing says which is which, and one that cannot be listed is `make dist`
# reporting success over an archive it never actually wrote.
dist: container
	$(DOCKER) run --rm -v $(abs_top_builddir):/out $(CONTAINER_TAG) \
		sh -c 'set -eu; \
			make -C /src dist; \
			cd /src; \
			set -- *.tar.gz; \
			if [ "$$#" -eq 0 ] || [ "$$1" = "*.tar.gz" ]; then \
				echo "make dist produced no tarball" >&2; \
				exit 1; \
			fi; \
			if [ "$$#" -gt 1 ]; then \
				echo "more than one tarball in /src: $$*" >&2; \
				echo "remove the stale one; this target cannot tell which to ship" >&2; \
				exit 1; \
			fi; \
			if ! tar tzf "$$1" 2>/dev/null | grep -q .; then \
				echo "make dist reported success but $$1 is empty or unreadable" >&2; \
				echo "likely cause: automake 1.17+ defaults to the ustar archive" >&2; \
				echo "format, but busybox tar (the default on minimal images like" >&2; \
				echo "Alpine) cannot write it, so automake silently falls back to" >&2; \
				echo "am__tar=false -- install GNU tar (e.g. Alpine package \"tar\")" >&2; \
				echo "in the Containerfile" >&2; \
				exit 1; \
			fi; \
			cp "$$1" /out/'

# DESTDIR is required, not defaulted: with none given, mounting $(prefix)'s
# default (/usr/local) read-write into the container would write into the
# host's real system directory as the container's root, something a native
# `make install` could never do without sudo.
install: container
	@if [ -z "$(DESTDIR)" ]; then \
		echo "Error: DESTDIR is required"; \
		echo "Usage: make install DESTDIR=/path/to/stage"; \
		exit 1; \
	fi
	@mkdir -p $(DESTDIR)
	$(DOCKER) run --rm -v $(DESTDIR):/dest $(CONTAINER_TAG) \
		make -C /src install DESTDIR=/dest

clean-local:
	-rm -f .stamp-container-base
	-$(DOCKER) rmi $(CONTAINER_TAG)

endif
