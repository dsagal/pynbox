Python NativeClient Sandbox (pynbox)
====================================

The project provides a version of Python that runs in the NaCl (NativeClient)
sandbox. Most OS operations are unavailable, and access to the filesystem is
limited to the specified directories (similar to chroot or docker mounts).

Security is a major focus of NativeClient. It allows safely executing untrusted code, in this case the Python interpreter, and all Python code running in it, including native Python modules.

The Pynbox project make this functionality easy to set up and use, whether by installing pre-built packages, or building from source. It works on Mac, Windows, and Linux.

##### Contents
- [Quick Start](#quick-start)
- [More Access](#more-access)
- [Pynbox packages](#pynbox-packages)
- [Building packages from source](#building-from-source)
- [NaCl Background](#background)
- [Security Considerations](#security)

## <a name="quick-start"/> Quick Start

To use the pre-built sandbox, clone the project, pick a destination directory `DEST_DIR`, and run `./pynbox install`:

```bash
git clone https://github.com/dsagal/pynbox.git

cd pynbox
./pynbox install DEST_DIR python tests

DEST_DIR/bin/test_pynbox
```

This installs the packages containing the sandbox, the Python 2.7 interpreter, and a test, and
runs the test. It should work on Mac, Windows, and Linux. If the output ends with "All passed",
then things are good. If not, please open an issue.

You can now run Python in a sandbox:

```bash
DEST_DIR/bin/run python -c 'import os; print os.listdir("/")'
>>> ['python', 'slib', 'test']
```

By default, the Python code only has read-only access to `DEST_DIR/root`. It can't see anything else.

On Windows, this process is tested with the Bash shell that comes with
[Git](https://git-scm.com/download/win). Note that on Windows, the sandboxed code sees a
POSIX-like filesystem.


## <a name="more-access"/> More Access

To allow the sandboxed code to interact with the outside world, `DEST_DIR/bin/run` supports a number
of options, which you can see by running `DEST_DIR/bin/run` with no arguments.

To give the script access to more of the filesystem, use the `-m <host_dir>:<virt_dir>:<ro|rw>`
option. It mounts the directory `<host_dir>` (on your machine) under the virtual paths
`<virt_dir>` where it will be seen by the sandboxed code. The suffix of `ro` or
`rw` determines whether to mount the directory as read-only or read-write. (If
you've used Docker, this option is similar to Docker's `-v`.)

Another connection to the outside world is the standard streams (stdin, stdout, sterr) and
additional file descriptors which you can redirect using `-h`, `-r`, and `-w` options to
`DEST_DIR/bin/run`.

What you can do with those is up to you. For example, you can run code inside and outside of the
sandbox, which sets ups RPC using forwarded file descriptors.

### Note
On Windows, the `run` script does not pass along open file descriptors to child
processes. If you need to use `-h`, `-r`, or `-w` options, run `VERBOSE=1 DEST_DIR/bin/run` to get
the underlying `sel_ldr` command line, and execute that command directly, bypassing the `run`
script.


## <a name="pynbox-packages"/> Pynbox packages

The `pynbox install` command allows installing several packages. Here's a brief description:

* `sandbox_outer` is always required and automatically added when installing anything. It includes
  the `run` convenience script, and `sel_ldr` which is the actual trusted loader: it is
  responsible for loading, validating, and running sandboxed code and enforcing the sandbox
  restrictions. Note that this package is OS-specific, so comes with .win, .mac, and .linux
  suffixes, and it is the only OS-specific package.

* `sandbox_inner` is also required and automatically added when installing anything. It contains
  some helper libraries that run inside the sandbox, in particular for dynamic library loading.

* `python` package contains Python 2.7 built to run in the sandbox.

* `lxml` package contains the Python `lxml` library, which includes a native module. It
  illustrates how native modules can be made to work in the sandbox.

Note that except for `sandbox_outer`, packages are not OS-specific. However, packages are
specific to CPU architecture, and currently only x86-64 (aka AMD64) is supported.

## <a name="building-from-source"/> Building packages from source

Prerequisites:
- x86-64 (aka AMD64) CPU architecture. This covers most modern machines, including laptops and
  desktops. NaCl supports more architectures, but you'll have to edit pynbox scripts to make that
  work.
- Docker for building OS-independent packages (all internal packages, i.e. all other than
  `sandbox_outer`). These packages can be used with any OS.
- Bash is required. On Windows, it is tested with Bash that comes with [Git](https://git-scm.com/download/win).
- On Windows, Visual Studio 2013 (vs120) is required, available
  [here](https://www.visualstudio.com/en-us/news/releasenotes/vs2013-community-vs) (no need to
  select any options), because nacl's scons build script fails to detect the presence of the newer
  VS 2015 version.

The following command builds all the packages we support at the moment.

```bash
./pynbox build sandbox_outer sandbox_inner python lxml tests
```

Note that `lxml` is an example of a Python module with native (binary) code. Most Python modules
do not require building, but only need to be placed somewhere under `DEST_DIR/root`, to be visible
inside the sandbox.

### Managing the Docker build

Packages internal to the sandbox are OS-independent, and built using Docker. These are known as
"webports". When running `./pynbox build` to build them, it automatically creates a Docker image
named `pynbox-webports` and runs it as a Docker container named `pynbox-webports1`. It then
executes commands within that Docker container.

You can start and stop the Docker container without building anything using `./pynbox startdocker`
and `./pynbox stopdocker` commands.

### Pynbox modifications

For building from source, Pynbox uses cloned repositories for NativeClient (the sandbox runner and
libraries), and for Webports (software packages that have been made to build under the sandbox).

* NativeClient uses https://github.com/dsagal/native_client.git, which is a clone of
  https://chromium.googlesource.com/native_client/src/native_client.git. The changes in the cloned
  repo are on the branch `windows_mount`. These changes include support for Docker-style mounts,
  including support for Windows, multiple mounts, and read-only mounts. It is essentially a
  re-implementation of the `sel_ldr` feature to offer restricted filesystem access.

  It is a lot of changes that are very useful and powerful, and Windows support makes the entire
  approach cross-platform. The hope is that they will be accepted upstream. See [Security
  Considerations](#security) below for impact on security.

* Webports use https://github.com/dsagal/webports.git, which is a clone of
  https://chromium.googlesource.com/webports. It includes fixes to the Python build instructions
  to make it work under `sel_ldr` (i.e. without Chrome, and with support for native modules), and
  also instructions for the `lxml` python module (along with libxslt and libxml libraries that it
  relies on).

### Installing from built packages

If you've built your own packages, e.g. after modifying their source code, the built packages end
up in `./build/packages/PACKAGE.VERSION.tgz2`. If you then run `./pynbox install`, they should be
picked up and installed into your destination directory.

Note: if you already have the same version of a package installed in `DEST_DIR`, subsequent
installations will skip it. To force a reinstall, remove the "install receipt" file
`DEST_DIR/packages/PACKAGE.installed` first. Alternatively, you can update a package's version
(e.g. by adding `-dev1` suffix) in `./packages/PACKAGE.create.sh`.

You may place your built packages in a separate directory (or online at some URL), and you'll then
be able to install from there by using `./pynbox install --repo REPO` option. This allows you to
build webports packages on one OS, and use the built packages on other OS's.


## <a name="background"/> NaCl Background

[NativeClient](https://developer.chrome.com/native-client) (or NaCl, and a
variant called PNaCl) is a sandbox for running native code in the Google Chrome
browser. The approach involves building the C or C++ code using NaCl suite of
tools (compiler, linker, etc) which produce binaries that verifiably access
only certain APIs (not OS directly), and then running them in an environment (typically
Chrome browser) which provides the necessary APIs.

The NaCl project is developed by Google, but is [open
source](http://www.chromium.org/nativeclient), as part of the Chromium project
(the open-source version of Google Chrome).

There are pretty good resources for building native apps using NaCl to run in
Chrome. What's not common is to run the NaCl sandbox without Chrome. The sandbox
comes with a tool for just that, `sel_ldr` (for Secure ELF Loader). It's no longer
used by Chrome itself, so is less well documented, and less well supported and
maintained.

NativeClient project includes a set of ports, known as
[webports](https://chromium.googlesource.com/webports/) which are software
packages that have been made to build under NaCl to run in Chrome.

One of the ports is
[Python](https://chromium.googlesource.com/webports/+/pepper_47/ports/python/README.nacl),
which makes Python interactive shell work under Chrome. It can also run under
`sel_ldr`.

The `sel_ldr` runner can enable access to the filesystem, including a
restricted mode when it limits access to a given directory (similarly to
chroot). If populated with all the modules and libraries that Python need, this
offers a way to run Python with that directory as the
filesystem root.

### NaCl vs PNaCl

NativeClient encompasses PNaCl (portable native client) and just NaCl. These
differ in toolchains used to build code, and produce .pexe and .nexe files
respectively. The idea is that .nexe is architecture-specific, and .pexe is
more portable: it can be translated to a suitable .nexe file on the fly.

There is a hitch, however: shared libraries are only supported by the glibc
toolchain which builds architecture-specific .nexe files directly. We need
shared libraries, in particular, to allow Python to load C extension modules
(including a number of standard modules).

Note: Loading shared libraries uses "libdl.so" library. This library isn't part of
NativeClient source. It is downloaded as part of an architecture specific tgz
archive (for each architecture). It seems to have some bugs (or super-weird
behavior), in particular opening "/lib/foo" translates to "/foo", while
"/./lib/foo" works. This is special for the "/lib" path, so we avoid the bug in
pynbox setup by placing libraries in the sandbox under "/slib" instead of "/lib".


## <a name="security"/> Security Considerations

If you are considering sandboxing, then security is important to you.

NativeClient itself has a robust design to ensure security. Here's Chrome's brief
[security FAQ](https://developer.chrome.com/native-client/faq#security-and-privacy). Google has
also published a paper about it: 
[Native Client: A Sandbox for Portable, Untrusted x86 Code](https://research.google.com/pubs/archive/34913.pdf) (PDF). Another analysys by Chris Rohlf is available here: [Analysis Of A Secure Browser Plugin Sandbox](https://media.blackhat.com/bh-us-12/Briefings/Rohlf/BH_US_12_Rohlf_Google_Native_Client_WP.pdf) (PDF).

Overall, the security approach of NativeClient relies on verifying instructions, preventing new
unverified instructions from being created at runtime, verifying that all jumps land
on verified addresses, and providing a suite of build tools that produce code that can pass these
verifications. The build tools themselves aren't trusted: the verifications happen at load time
and run time.

There is other trusted code that implements allowed system calls and other communication between
the sandbox and the outside world.

The design is robust and powerful, but bugs will exist as anywhere, and these can cause
vulnerabilities that allow untrusted code to escape the sandbox. This post includes a great
discussion and lists some examples from a security contest in 2009: [Security
Implications](https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2009/august/the-security-implications-of-google-native-client/).

So the biggest risk to NativeClient's security is if it is little-used, and nobody spends the time
to discover and fix vulnerabilities.

### Python layer

If you only use Pynbox to run Python code (and not to run untrusted native code), it mitigates
many risks, since Python code doesn't have a direct way to execute CPU instructions or
manipulate the format of the executable, which is the basis for various attempted exploits.

### Modifications by Pynbox

Pynbox adds features to the trusted code that have seen less vetting than other code. Namely, it
adds support for mounting multiple directories from the host system, including new support for
Windows and for read-only mounts. The code is written with security in mind, but has been less
tested than those parts of NativeClient codebase that are used in Chrome.

With mounted directories, one area of concern is symlinks. In short, it is recommended to avoid
symlinks in mounted directories. If you have symlinks in the mounted directories that point
outside, the trusted code follows them and interprets them as inside the virtual filesystem (e.g.
`HOST_DIR/foo -> /etc/passwd` would translate to  `HOST_DIR/etc/passwd`). This is good.
However, there is a race
condition between this verification and actual operations on the file. If a new symlink is created
along the resolved path between the resolution and the actual operation, it may allow an escape
outside of the mounted directories. For this reason, creation of symlinks, and renames of symlinks
or directories are disallowed for sandboxed code, so such an exploit is only possible with help
from code running outside of the sandbox.

### We want to hear from you

If you have discover vulnerabilities or have questions about security, please get in touch at
dmitry at getgrist.com, or open an issue.
