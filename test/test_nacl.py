import os
import sys
import unittest

class TestNaclSandbox(unittest.TestCase):
  #----------------------------------------------------------------------
  # Verify that various OS services are blocked.
  #----------------------------------------------------------------------
  def test_socket(self):
    import socket
    with self.assertRaisesRegexp(EnvironmentError, r'not implemented'):
      socket.socket(socket.AF_INET, socket.SOCK_STREAM)

  def test_pipe(self):
    with self.assertRaisesRegexp(EnvironmentError, r'not implemented'):
      os.pipe()

  def test_popen(self):
    with self.assertRaisesRegexp(EnvironmentError, r'not implemented'):
      os.popen("echo asdf")

  def test_subprocess(self):
    import subprocess
    with self.assertRaisesRegexp(EnvironmentError, r'not implemented'):
      subprocess.check_output(["ls", "-l"])

  def test_fork(self):
    with self.assertRaisesRegexp(EnvironmentError, r'not implemented'):
      p = os.fork()
      if p == 0:    # If we do succeed, the child process shouldn't keep running.
        sys.exit(0)

  def test_kill(self):
    with self.assertRaisesRegexp(EnvironmentError, r'not implemented'):
      os.kill(0, 0)

  def test_waitpid(self):
    # Note that this test was causing Python interpreter to crash with "Bus error" in the
    # unmodified webports version.
    with self.assertRaisesRegexp(EnvironmentError, r'not implemented'):
      os.waitpid(0, 0)

  def test_wait4(self):
    # Note that this test was causing Python interpreter to crash with "Bus error" in the
    # unmodified webports version.
    with self.assertRaisesRegexp(EnvironmentError, r'not implemented'):
      os.wait4(0, 0)

  #----------------------------------------------------------------------
  # Test that filesystem works but is limited.
  #----------------------------------------------------------------------

  def test_filesystem_root(self):
    root_files = os.listdir("/")
    self.assertIn("lib", root_files)
    self.assertIn("python", root_files)
    self.assertNotIn("usr", root_files)
    self.assertNotIn("etc", root_files)

    python_files = os.listdir("/python")
    self.assertIn("lib", python_files)
    self.assertIn("bin", python_files)

  def test_file_read(self):
    with self.assertRaisesRegexp(EnvironmentError, r'No such file'):
      open("/etc/passwd")

    os_module_piece = open("/python/lib/python2.7/os.py", "r").read(1024)
    self.assertIn("OS routines", os_module_piece)

  def test_file_write(self):
    path = "/tmpfile.deleteme"
    if os.path.exists(path):
      os.remove(path)

    with open(path, "w") as f:
      f.write("hello\n")
    self.assertTrue(os.path.exists(path))
    self.assertEqual(open(path).read(), "hello\n")
    os.remove(path)
    self.assertFalse(os.path.exists(path))

  #----------------------------------------------------------------------
  # Test that various other modules work.
  #----------------------------------------------------------------------

  def test_time(self):
    import time
    t = time.time()
    # Check the time is remotely realistic.
    self.assertTrue(t > 1400000000 and t < 3400000000)

  def test_datetime(self):
    import datetime
    now = datetime.datetime.now()
    self.assertEqual(datetime.date.today(), now.date())
    self.assertTrue(now.year >= 2016 and now.year < 2100)
    self.assertTrue(now.strftime("%Y/%m/%d %H:%M:%S").startswith(str(now.year)))

  def test_array(self):
    import array
    a = array.array('i', range(0, 5))
    a.byteswap()
    self.assertEqual(a.tolist(), [0, 0x1000000, 0x2000000, 0x3000000, 0x4000000])

  def test_hashlib(self):
    import hashlib
    data = "0123456789" * 1000 + "\n"
    self.assertEqual(hashlib.md5(data).hexdigest(), "3f34933902c95884886366c31d2b26b4")
    self.assertEqual(hashlib.sha1(data).hexdigest(), "9319b3421c7cd90556ff161310432f7e90a5357d")
    self.assertEqual(hashlib.sha256(data).hexdigest(),
                     "199fe5ab802f2a2b7403ffe655560dbaa495cc0c02dc6b244446afb2bd89ad26")

  def test_zlib(self):
    import zlib
    data = "0123456789" * 1000
    compressed = zlib.compress(data)
    self.assertLess(len(compressed), 100)
    self.assertEqual(zlib.decompress(compressed), data)

  def test_world_of_modules(self):
    # Check that we can import all imaginable modules without errors.
    import pkgutil, re
    ignore = {'antigravity', 'this'}    # silly easter eggs we don't want to import
    missing_dependencies = set()
    other_failures = set()
    for _, name, _ in pkgutil.iter_modules():
      if name in ignore:
        continue
      try:
        __import__(name)
      except Exception, e:
        m = re.search(r'No module named (\w+)', e.message)
        if m:
          missing_dependencies.add(m.group(1))
        else:
          other_failures.add(name)

    KNOWN_MISSING = {'_sqlite3', '_bsddb', '_tkinter'}
    KNOWN_FAILURES = {'_multiprocessing', '_MozillaCookieJar', '_LWPCookieJar', 'multiprocessing'}
    self.assertLessEqual(missing_dependencies, KNOWN_MISSING)
    self.assertLessEqual(other_failures, KNOWN_FAILURES)

if __name__ == "__main__":
  unittest.main()
