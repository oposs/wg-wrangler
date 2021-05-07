WGwrangler
===========
Version: 0.1.0
Date: 2021-04-16

WGwrangler is a web application to manage local Wireguard Configuration using 
[wg-meta](https://metacpan.org/release/Wireguard-WGmeta) in its backend. 

It comes complete with a classic "configure - make - install" setup.

Setup
-----
In your app source directory and start building.

```console
# Install os dependencies
sudo apt install libqrencode-dev

./configure --prefix=$HOME/opt/wgwrangler
make
```

Configure will check if all requirements are met and give
hints on how to fix the situation if something is missing.

Any missing perl modules will be downloaded and built.

Development
-----------

While developing the application it is convenient to NOT have to install it
before runnning. You can actually serve the Qooxdoo source directly
using the built-in Mojo webserver.

```console
./bin/wgwrangler-source-mode.sh
```

You can now connect to the CallBackery app with your web browser.

If you need any additional perl modules, write their names into the PERL_MODULES
file and run ./bootstrap.

**Honored Environment Variables**

- `WGwrangler_NO_WG` If defined, we do not call any wg* command from code (e.g. to generate pub/private-keys)
- `WGwrangler_CONFIG` Use this variable to set the path to the main `wgwrangler.yaml` file, defaults to `etc/wgrangler.yaml`

Installation
------------

To install the application, just run

```console
make install
```

You can now run wgwrangler in reverse proxy mode.

```console
cd $HOME/opt/wgwrangler/bin
./wgwrangler prefork
```

OS Preparation
-------------

Since managing wireguard using its associated `wg*` commands requires root privileges we suggest the following
setup:

- Create a separate user/group e.g `wireguard_manager`
- Whitelist the `wg` commands for this group in the `/etc/sudoers` file:
  ```text
  %wireguard_manager ALL=NOPASSWD: /usr/bin/wg*
  ```
- Set `wireguard_manger` as group on `/etc/wireguard` and adjust permissions to `g+rwx`
- Additionally, creating a `wg-wrangler.service` file may improve usability quite a bit:
  ```text
  # This is to be considered as a (very) simple example of such a .service file
  [Unit]
  Description=wg-wranger wireguard manager
  
  [Service]
  Type=simple
  User=wireguard_manager
  Group=wireguard_manager
  ExecStart=/usr/bin/perl /home/wireguard_manager/opt/wgwrangler/bin/wgwrangler prefork --listen 'http://127.0.0.1:7171'
  
  [Install]
  WantedBy=multi-user.target
   ```

Packaging
---------

Before releasing, make sure to update `CHANGES`, `VERSION` and run
`./bootstrap`.

You can also package the application as a nice tar.gz file, it uses carton to
install dependent module. If you want to make sure that your project builds with perl
5.22, make sure to set the `PERL` environment variable to a perl 5.22
interpreter, make sure to delete any `PERL5LIB` environment variable, and run
`make clean && make`. This will cause a `cpanfile-0.1.0.snapshot` file to be included
with your tar ball, when building the app this snapshot will be used to make sure
all the right versions of the dependent modules get installed.

```console
make dist
```

Screenshots
-----------

![](.github/img/overview.png)

![](.github/img/create.png)

![](.github/img/email.png)


Enjoy!

Tobias Bossert <bossert _at_ oetiker _this_is_a_dot_ ch>
