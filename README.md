Python NativeClient Sandbox (pynbox)
====================================

The project helps build a version of Python that runs in NaCl (NativeClient)
sandbox. Most OS operations are unavailable, and access to the filesystem is
limited to the specified directories (similar to chroot or docker mounts).

Security is a major focus of NativeClient. It allows safely executing untrusted code, in this case the Python interpreter, and all Python code running in it, including native Python modules.

This project make this easy to set up.

Quick Start
-----------

To use the pre-built sandbox, clone the project, pick a destination directory, and run `pynbox install`:

```bash
git clone https://github.com/dsagal/pynbox.git
./pynbox install DEST python tests
DEST/bin/test_pynbox
```

This installs the packages containing the sandbox, the Python 2.7 interpreter, and a test, and runs the test. If the output ends with "All passed", then things are good. If not, please open an issue.

You can now run Python in a sandbox:

```bash
DEST/bin/run python -c 'import os; print os.listdir("/")'
>>> ['python', 'slib', 'test']
```

By default, the Python code only has read-only access to `DEST/root`. It can't see anything else.

Giving more access
------------------

To allow the sandboxed code to interact with the outside world, `DEST/bin/run` supports a number of options:

```bash
DEST/bin/run
```

shows all available flags.

To give the script access to other directories in the filesystem, or to give it
read-write access, use the `-m <host_dir>:<virt_dir>:<ro|rw>` option. It mounts
the directory `<host_dir>` (on your machine) under the virtual paths
`<virt_dir>` where it will be seen by the sandbox. The suffix of `ro` or `rw`
determines whether to mount the directory as read-only or read-write. (If
you've used Docker, you might recognize this option as similar to Docker's `-v`
option.)

The other connection to the outside world are the standard streams (stdin,
stdout, sterr) and file descriptos which you can redirect using `-h`, `-r`, and
`-w` options to `DEST/bin/run`.

What you can do with those is up to you. For example, you can run code inside and outside of the sandbox, which sets ups RPC using forwarded file descriptors.


Building packages from source
-----------------------------

Prerequisites:
- At this time only x86-64 CPU architecture is supported (NaCl
  supports more, but you'll have to edit pynbox scripts to make get it to work).
- Building packages internal to the sandbox, which is everything except
  `sandbox_outer` does NOT depend on the OS, only on the architecture. Pynbox
  builds them using Docker, to ensure a consistent environment.
- Building `sandbox_outer` produces a package specific to the current OS.

The following command builds all the packages we support at the moment.

```bash
./pynbox build sandbox_inner sandbox_outer python lxml tests
```

Note that `lxml` is an example of a native (binary) Python module. Most Python modules do not require building, but only need to be placed somewhere under `DEST/root`, to be visible inside the sandbox.


NaCl Background
----------

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
Chrome. What's not common is to run NaCl sandbox without Chrome. The sandbox
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

Notes
-----
NativeClient encompasses PNaCl (portable native client) and just NaCl. These
differ in toolchains used to build code, and produce .pexe and .nexe files
respectively. The idea is that .nexe is architecture-specific, and .pexe is
more portable: it can be translated to a suitable .nexe file on the fly.

There is a hitch, however: shared libraries are only supported by the glibc
toolchain which builds architecture-specific .nexe files directly. We need
shared libraries, in particular, to allow Python to load C extension modules
(including some standard ones).

Loading shared libraries uses "libdl.so" library. This library isn't part of
NativeClient source. It is downloaded as part of an architecture specific tgz
archive (for each architecture). It seems to have some bugs (or super-weird
behavior), in particular opening "/lib/foo" translates to "/foo", while
"/./lib/foo" works. This is special for the "/lib" path, so we avoid it by
putting libraries under "/slib".
