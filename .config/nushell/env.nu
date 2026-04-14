use user.nu
use user cdk
user present
export use "completions.nu" *

# configure direnv
$env.config.hooks.env_change.PWD = []
$env.config.hooks.env_change.PWD = (
  $env.config.hooks.env_change.PWD | append (source nu_scripts/nu-hooks/nu-hooks/direnv/config.nu)
)

$env.PATH = $env.PATH | append ~/.cargo/bin
$env.PATH = $env.PATH | prepend "/home/luca/.wasmtime/bin"

