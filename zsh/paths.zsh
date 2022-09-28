# Brew
export PATH="$(brew --prefix)/opt/coreutils/libexec/gnubin:$PATH"
export PATH="$(brew --prefix)/bin:$PATH"

# local
export PATH="$HOME/.local/bin:$PATH"

# bun
export BUN_INSTALL="/Users/vgapurov/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# TMP JAVA for openapi-generator
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-12.0.2.jdk/Contents/Home/
