# sublime-config

## Snippets

```bash
ln -s /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl /usr/local/bin/subl
PKG_USER="/Users/`whoami`/Library/Application Support/Sublime Text 3/Packages/User/"
mkdir -p "${PKG_USER}"
cp snippets/* "${PKG_USER}"
find "${PKG_USER}" -name "*.sublime-*" -exec rm -f {} \;
cp settings/* "${PKG_USER}"
```

## Plugins

* `Babel`
* `DocBlockr`
* `Git`
* `GitGutter`
* `GoSublime`
* `JsPrettier`
* `Markdown Preview`
* `SideBarEnhancements`
* `SublimeLinter`
* `SublimeLinter-contrib-eslint`
* `SublimeLinter-contrib-stylelint`
* `Sublimerge 3`
