dnl repo-infra: container-m4 v2
dnl
dnl Purpose: The container-driver mode switch for configure.ac (D18).
dnl Choose: With container.
dnl Supplies: The macro call in configure.ac.
dnl
dnl The container-driver mode switch (D18).
dnl
dnl repo-infra owns this file. The project owns its Containerfile and what goes
dnl in it. Call this from configure.ac, then wrap the project's own dependency
dnl checks so they never run on a host that is only driving the container:
dnl
dnl     REPO_INFRA_CONTAINER
dnl     AS_IF([test "x$enable_container" = xno], [
dnl       dnl librrd, RRDs, everything real -- probed here and nowhere else
dnl     ])
dnl
dnl The default is the role you do not control: someone clones the repository
dnl and types ./configure && make, and it works on a machine holding none of
dnl the project's dependencies, because the container carries them.
dnl
dnl --disable-container names the semantics, not a location: it means "do the
dnl real build in this tree". The Containerfile passes it, and so does a distro
dnl packager on a bare build host, who wants the same behaviour and is not in a
dnl container.

AC_DEFUN([REPO_INFRA_CONTAINER], [
  AC_ARG_ENABLE([container],
    [AS_HELP_STRING([--disable-container],
       [build in this tree instead of driving a container])],
    [], [enable_container=yes])

  AS_IF([test "x$enable_container" = xyes], [
    AC_CHECK_PROGS([DOCKER], [podman docker])
    AS_IF([test -z "$DOCKER"],
      [AC_MSG_ERROR([no container engine found. Install podman, or pass --disable-container to build in this tree.])])
    AS_IF([test -f "$srcdir/Containerfile"], [],
      [AC_MSG_ERROR([no Containerfile in $srcdir -- write one, or pass --disable-container to build in this tree.])])
  ])

  AM_CONDITIONAL([CONTAINER_DRIVER], [test "x$enable_container" = xyes])
])
