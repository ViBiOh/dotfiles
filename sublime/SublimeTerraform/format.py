import sublime
import sublime_plugin
import subprocess


class TerraformFmt(sublime_plugin.TextCommand):
    def run(self, edit):
        view = self.view
        if not view.match_selector(0, 'source.terraform'):
            return

        region = sublime.Region(0, view.size())
        src = view.substr(region)

        vars = view.window().extract_variables()
        working_dir = vars['file_path']

        terraform_format = subprocess.Popen(['terraform', 'fmt', '-'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=working_dir)
        terraform_format_out, terraform_format_err = terraform_format.communicate(src.encode())
        if terraform_format.returncode != 0:
            print(goimports_err.decode(), end="")
            return

        view.replace(edit, region, terraform_format_out.decode())


class GoformatOnSave(sublime_plugin.EventListener):
    def on_pre_save(self, view):
        view.run_command('terraform_fmt')
