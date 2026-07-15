import os
import signal
import subprocess
import threading


class AsyncTask:
    encoding = "utf-8"

    def __init__(self, command=["printf", "Hello"], cwd=None, env=None, output=print):
        self.output = output
        self.killed = False
        self.proc = None

        self.write("# {}\n".format(cwd))
        self.write(" ".join(command) + "\n\n")

        try:
            self.proc = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                cwd=cwd,
                env=env,
                start_new_session=True,
            )

            threading.Thread(target=self.read, args=(self.proc.stdout,)).start()

        except Exception as e:
            self.write("[exception]\n" + repr(e))

    def enabled(self, kill=False):
        if kill:
            return self.proc is not None and self.proc.poll() is None

        return False

    def kill(self):
        proc = self.proc
        if proc is None:
            return

        self.killed = True
        self.proc = None

        try:
            pgid = os.getpgid(proc.pid)
        except ProcessLookupError:
            return

        try:
            os.killpg(pgid, signal.SIGTERM)
        except ProcessLookupError:
            return

        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(pgid, signal.SIGKILL)
            except ProcessLookupError:
                return
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                print("unable to kill process group {}".format(pgid))

    def read(self, reader):
        for line in reader:
            try:
                self.write(line.decode(self.encoding))
            except UnicodeDecodeError:
                self.write(line.hex() + "\n")

        if self.killed:
            msg = "Cancelled"
        else:
            msg = "Finished"

        self.write("\n[%s]" % msg)

        reader.close()

    def write(self, text):
        self.output(text)
