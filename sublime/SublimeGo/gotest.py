import sublime, sublime_plugin, subprocess, os, threading

class GoTest(sublime_plugin.WindowCommand):
	encoding = 'utf-8'
	killed = False
	proc = None
	panel = None
	panel_lock = threading.Lock()

	def is_enabled(self, kill=False):
		if kill:
			return self.proc is not None and self.proc.poll() is None

		return True

	def run(self, kill=False):
		if kill:
			if self.proc:
				self.killed = True
				self.proc.terminate()

			return

		vars = self.window.extract_variables()
		working_dir = vars['file_path']

		with self.panel_lock:
			self.panel = self.window.create_output_panel('gotest')
			self.window.run_command('show_panel', {'panel': 'output.gotest'})

		if self.proc is not None:
			self.proc.terminate()
			self.proc = None

		self.queue_write('Running go test...\n')
		self.proc = subprocess.Popen(['go', 'test', '-cover', '-race'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=working_dir)
		self.killed = False

		threading.Thread(
			target=self.read_handle,
			args=(self.proc.stdout,)
		).start()

	def read_handle(self, handle):
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

				self.queue_write(out.decode(self.encoding))
				if data == b'':
					raise IOError('EOF')

				out = b''

			except (UnicodeDecodeError) as e:
				msg = 'Error decoding output using %s - %s'
				self.queue_write(msg  % (self.encoding, str(e)))
				break

			except (IOError):
				if self.killed:
					msg = 'Cancelled'
				else:
					msg = 'Finished'
					self.queue_write('\n[%s]' % msg)
				break

	def queue_write(self, text):
		sublime.set_timeout(lambda: self.do_write(text), 1)

	def do_write(self, text):
		with self.panel_lock:
			self.panel.run_command('append', {'characters': text})
