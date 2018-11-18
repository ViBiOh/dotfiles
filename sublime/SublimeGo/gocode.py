import sublime, sublime_plugin, subprocess, threading
from . async_task import AsyncTask

# go to balanced pair, e.g.:
# ((abc(def)))
# ^
# \--------->^
#
# returns -1 on failure
def skip_to_balanced_pair(str, i, open, close):
	count = 1
	i += 1
	while i < len(str):
		if str[i] == open:
			count += 1
		elif str[i] == close:
			count -= 1

		if count == 0:
			break
		i += 1
	if i >= len(str):
		return -1
	return i

# split balanced parens string using comma as separator
# e.g.: "ab, (1, 2), cd" -> ["ab", "(1, 2)", "cd"]
# filters out empty strings
def split_balanced(s):
	out = []
	i = 0
	beg = 0
	while i < len(s):
		if s[i] == ',':
			out.append(s[beg:i].strip())
			beg = i+1
			i += 1
		elif s[i] == '(':
			i = skip_to_balanced_pair(s, i, "(", ")")
			if i == -1:
				i = len(s)
		else:
			i += 1

	out.append(s[beg:i].strip())
	return list(filter(bool, out))


def extract_arguments_and_returns(sig):
	sig = sig.strip()
	if not sig.startswith("func"):
		return [], []

	# find first pair of parens, these are arguments
	beg = sig.find("(")
	if beg == -1:
		return [], []
	end = skip_to_balanced_pair(sig, beg, "(", ")")
	if end == -1:
		return [], []
	args = split_balanced(sig[beg+1:end])

	# find the rest of the string, these are returns
	sig = sig[end+1:].strip()
	sig = sig[1:-1] if sig.startswith("(") and sig.endswith(")") else sig
	returns = split_balanced(sig)

	return args, returns

# takes gocode's candidate and returns sublime's hint and subj
def hint_and_subj(cls, name, type):
	subj = name
	hint = '{} {}'.format(cls, name)

	if cls == 'func':
		args, returns = extract_arguments_and_returns(type)

		if returns:
			hint += '\t' + ', '.join(returns)

		if args:
			sargs = []
			for i, a in enumerate(args):
				ea = a.replace('{', '\\{').replace('}', '\\}')
				sargs.append("${{{0}:{1}}}".format(i+1, ea))
			subj += '(' + ', '.join(sargs) + ')'
		else:
			subj += '()'

	else:
		hint += '\t' + type

	return hint, subj


class GocodeUpdate(sublime_plugin.WindowCommand):
	proc = None
	task = None
	panel = None
	panel_lock = threading.Lock()

	def run(self):
		vars = self.window.extract_variables()
		working_dir = vars['file_path']

		with self.panel_lock:
			self.panel = self.window.create_output_panel('gocode')
			self.window.run_command('show_panel', {'panel': 'output.gocode'})

		self.queue_write('Updating gocode...\n')
		self.task = AsyncTask(command=['go', 'build', '-i', './...'], output=self.queue_write, cwd=working_dir)

	def queue_write(self, text):
		sublime.set_timeout(lambda: self.do_write(text), 1)

	def do_write(self, text):
		with self.panel_lock:
			self.panel.run_command('append', {'characters': text})


class Gocode(sublime_plugin.EventListener):
	def on_query_completions(self, view, prefix, locations):
		if not view.match_selector(0, 'source.go'):
			return

		src = view.substr(sublime.Region(0, view.size()))

		gocode = subprocess.Popen(['gocode', '-f=csv', '-builtin', '-ignore-case', 'autocomplete', view.file_name(), 'c{0}'.format(locations[0])], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		out, err = gocode.communicate(src.encode())
		if gocode.returncode != 0:
			print('ERROR gocode: {}'.format(err.decode()))
			return

		has_invalid = False
		results = []
		for line in filter(bool, out.decode().split('\n')):
			arg = line.split(',,')
			hint, subj = hint_and_subj(arg[0], arg[1], arg[2])
			results.append([hint, subj])

			if 'invalid type' in hint:
				has_invalid = True

		if has_invalid:
			view.run_command('gocode_update')

		return (results, sublime.INHIBIT_WORD_COMPLETIONS)
