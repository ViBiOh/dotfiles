import subprocess, os, threading


class AsyncTask:
    encoding = 'utf-8'
    killed = False
    proc = None

    def __init__(self, command=['echo', 'Hello World'], cwd=None, output=print):
        self.output = output

        if self.proc is not None:
            self.proc.terminate()
            self.proc = None

        self.proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=cwd)
        self.killed = False

        threading.Thread(
            target=self.read,
            args=(self.proc.stdout,)
        ).start()

    def enabled(self, kill=False):
        if kill:
            return self.proc is not None and self.proc.poll() is None

    def kill(self):
        if self.proc:
            self.killed = True
            self.proc.terminate()

    def read(self, handle):
        chunk_size = 2 ** 13
        out = b''

        while True:
            try:
                data = os.read(handle.fileno(), chunk_size)

                out += data
                if len(data) == chunk_size:
                    continue

                if data == b'' and out == b'':
                    raise IOError('EOF')

                self.write(out.decode(self.encoding))
                if data == b'':
                    raise IOError('EOF')

                out = b''

            except (UnicodeDecodeError) as e:
                msg = 'Error decoding output using %s - %s'
                self.write(msg % (self.encoding, str(e)))
                break

            except (IOError):
                if self.killed:
                    msg = 'Cancelled'
                else:
                    msg = 'Finished'

                self.write('\n[%s]' % msg)
                break

    def write(self, text):
        self.output(text)
