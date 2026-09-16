import os
import signal
import subprocess
import threading
from typing import Any, Dict


def no_window_kwargs() -> Dict[str, Any]:
    """Extra subprocess kwargs that keep the child's console window hidden. Empty on
    POSIX, where CREATE_NO_WINDOW does not exist and there is no window to hide."""
    creationflags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    if not creationflags:
        return {}

    startupinfo = subprocess.STARTUPINFO()
    startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startupinfo.wShowWindow = subprocess.SW_HIDE

    return {"creationflags": creationflags, "startupinfo": startupinfo}


class AsyncTask:
    encoding = "utf-8"

    def __init__(
        self,
        command=["printf", "Hello"],
        cwd=None,
        env=None,
        output=print,
        on_finished=None,
    ):
        self.output = output
        self.on_finished = on_finished
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
                **no_window_kwargs(),
            )

            threading.Thread(
                target=self.read, args=(self.proc.stdout, self.proc)
            ).start()

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

    def read(self, reader, proc):
        for line in reader:
            try:
                self.write(line.decode(self.encoding))
            except UnicodeDecodeError:
                self.write(line.hex() + "\n")

        reader.close()

        if self.killed:
            self.write("\n[Cancelled]")
            return

        exit_code = proc.wait()
        self.write("\n[Finished]")

        if self.on_finished:
            self.on_finished(exit_code)

    def write(self, text):
        self.output(text)
