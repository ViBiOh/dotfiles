import sublime, sublime_plugin, subprocess

class GoFormat(sublime_plugin.TextCommand):
  def run(self, edit):
    view = self.view
    if not view.match_selector(0, 'source.go'):
      return

    region = sublime.Region(0, view.size())
    src = view.substr(region)

    goimports = subprocess.Popen(['goimports'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    goimports_out, goimports_err = goimports.communicate(src.encode())
    if goimports.returncode != 0:
      print(goimports_err.decode(), end="")
      return

    gofmt = subprocess.Popen(['gofmt', '-s'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    gofmt_out, gofmt_err = gofmt.communicate(goimports_out)
    if goimports.returncode != 0:
      print(gofmt_err.decode(), end="")
      return

    content = gofmt_out.decode()

    view.replace(edit, region, content)
