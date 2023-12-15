import os
import subprocess
import threading


class AsyncTask:
    encoding = "utf-8"
    killed = False
    proc = None

    def __init__(self, command=["printf", "Hello"], cwd=None, env=None, output=print):
        self.output = output

        if self.proc is not None:
            self.proc.terminate()
            self.proc = None

        self.write(" ".join(command) + "\n\n")

        self.proc = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            cwd=cwd,
            env=env,
        )
        self.killed = False

        threading.Thread(target=self.read, args=(self.proc.stdout,)).start()

    def enabled(self, kill=False):
        if kill:
            return self.proc is not None and self.proc.poll() is None

        return False

    def kill(self):
        if self.proc:
            self.killed = True
            self.proc.terminate()

    def read(self, reader):
        for line in reader:
            self.write(line.decode(self.encoding))

        if self.killed:
            msg = "Cancelled"
        else:
            msg = "Finished"

        self.write("\n[%s]" % msg)

        reader.close()

    def write(self, text):
        self.output(text)
