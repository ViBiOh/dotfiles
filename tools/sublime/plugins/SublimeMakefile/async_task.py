import binascii
import os
import re
import signal
import subprocess
import threading

pstree_pid = re.compile("- (?P<pid>[0-9]+) ")


class AsyncTask:
    encoding = "utf-8"
    killed = False
    proc = None

    def __init__(self, command=["printf", "Hello"], cwd=None, env=None, output=print):
        self.output = output

        if self.proc is not None:
            self.kill()

        self.write(" ".join(command) + "\n\n")

        try:
            self.proc = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                cwd=cwd,
                env=env,
            )
            self.killed = False

            threading.Thread(target=self.read, args=(self.proc.stdout,)).start()

        except Exception as e:
            self.write("[exception]\n" + getattr(e, "message", repr(e)))

    def enabled(self, kill=False):
        if kill:
            return self.proc is not None and self.proc.poll() is None

        return False

    def kill(self):
        if self.proc:
            self.killed = True

            self.kill_child()
            self.proc.terminate()
            self.proc = None

    def kill_child(self):
        try:
            child_processes = subprocess.check_output(
                ["pstree", str(self.proc.pid)],
                stderr=subprocess.STDOUT,
            )
        except subprocess.CalledProcessError as e:
            output = e.output.decode("utf8")
            if len(e.output.decode("utf8")) == 0:
                return

            print("unable to list child process: {}".format(output))
            return

        for line in child_processes.decode().rstrip().split("\n"):
            pid_match = pstree_pid.search(line)
            if pid_match:
                if (
                    subprocess.call(["kill", "-s", "SIGTERM", pid_match.group("pid")])
                    != 0
                ):
                    print("unable to kill {}".format(line))

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
