use std assert

export def relative_to_home [] {
    let p = $in
    match (do --ignore-errors { $p | path relative-to $nu.home-path }) {
        null => $p
        '' => '~'
        $relative_pwd => ([~ $relative_pwd] | path join)
    }
}

def branch_prompt [] {
    let user = whoami | str trim
    let hostname = hostname | str trim

    let path_color = (if (is-admin) { ansi red_bold } else { ansi green_bold })
    let separator_color = (if (is-admin) { ansi light_red_bold } else { ansi light_green_bold })
    let colored_sep = $"($separator_color)(char path_sep)"

    def color_path [] {
        $"($path_color)($in)" | str replace --all (char path_sep) $"($colored_sep)($path_color)"
    }

    # Helper: color path, gray for gitignored
    def color_path_gitignore [repo_root path_relative_to_repo path_color colored_sep] {
        let sep = (char path_sep)
        let parts = ($path_relative_to_repo | split row $sep | where {|x| $x != "" })
        mut acc = $repo_root
        mut colored = []
        for part in $parts {
            let next = ($acc | path join $part | path expand)
            let is_ignored = (do --ignore-errors { ^git check-ignore $"($next)/" | complete | get exit_code } | default 1) == 0
            let color = if $is_ignored { ansi grey } else { $path_color }
            $colored = ($colored | append $"($colored_sep)($color)($part)(ansi reset)")
            $acc = $next
        }
        $colored | str join ""
    }

    mut dir = $env.PWD | relative_to_home

    let branch_response = git branch --show-current | complete
    let prompt = if $branch_response.exit_code == 0 {
        let branch_response_lines = $branch_response.stdout | str trim | lines
        let branch = if ($branch_response_lines | length) == 0 {
            let hash = ^git rev-parse --short HEAD | str trim
            $"#($hash)"
        } else {
            $branch_response_lines.0
        }
        let repo_root = ^git rev-parse --show-toplevel | complete | get stdout | str trim | relative_to_home
        let repo_parent = $repo_root | path dirname
        let repo_name = ^basename $repo_root
        let path_relative_to_repo = match ($dir | path relative-to $repo_root) {
            "" => "",
            $relative => $relative
        }

        # add a link to the repo if we have one
        let repo_name_with_link = match (^git config --get remote.origin.url | complete | get stdout | str trim) {
            $url => ($url | ansi link --text $repo_name),
            "" => $repo_name,
        }

        let no_changes = (git diff-index --quiet HEAD -- | complete | get exit_code) == 0
        let unpushed = (git log --branches --not --remotes --max-count=1 | lines | length) > 0
        let unpulled = (git log --remotes --not --branches --max-count=1 | lines | length) > 0
        let staged = (git diff --staged --quiet | complete | get exit_code) == 1

        let unpushed_mark = if $unpushed { $"(ansi purple)↑(ansi reset)" } else { "" }
        let unpulled_mark = if $unpulled { $"(ansi red)↓(ansi reset)" } else { "" }
        let staged_mark = if $staged { $"(ansi yellow)●(ansi reset)" } else { "" }
        let color = if $no_changes { ansi grey } else { ansi xterm_gold3b }

        let branch_info = $"(ansi grey)\((ansi reset)($color)($branch)(ansi reset)($unpushed_mark)($unpulled_mark)($staged_mark)(ansi grey)\)(ansi reset)"

        let colored_path = if $path_relative_to_repo == "" {
            ""
        } else {
            color_path_gitignore $repo_root $path_relative_to_repo $path_color $colored_sep
        }

        $"($repo_parent | color_path)($colored_sep)($path_color)($repo_name_with_link)($branch_info)($colored_path)"
    } else {
        $dir | color_path
    };

    # ! TMP
    let prompt = $"(ansi grey)($user)@($hostname)(ansi reset):($prompt)"

    if ($prompt | ansi strip | str length) > 50 {
        $"(ansi cyan)╭╴(ansi reset)($prompt)\n(ansi cyan)╰╴(ansi reset)"
    } else {
        $prompt
    }
}


export def --env present [] {
    $env.PROMPT_COMMAND = {|| branch_prompt }
    let hostname = (try { open /etc/hostname | str trim } catch { "" })
    let m = match ($hostname | str trim) {
        "luca-VivoBook-ASUSLaptop-X580GD-N580GD" => $"  (ansi green_bold)Luca Ciucci @ Bugseng(ansi reset) <(ansi blue)luca.ciucci@bugseng.com(ansi reset)> <https://bugseng.com/>",
        _ => $"  (ansi green_bold)Luca Ciucci(ansi reset) <(ansi blue)luca.ciucci99@gmail.com(ansi reset)> <https://lucaciucci.github.io/>",
    }
    print $m
}

# Create a symlink
export def symlink [
    existing: path   # The existing file
    link_name: path  # The name of the symlink
] {
    # from the cookbook: https://www.nushell.sh/blog/2023-08-23-happy-birthday-nushell-4.html#crossplatform-symlinks-kubouch

    let existing = ($existing | path expand -s)
    let link_name = ($link_name | path expand)

    if $nu.os-info.family == 'windows' {
        if ($existing | path type) == 'dir' {
            ^mklink /D $link_name $existing
        } else {
            ^mklink $link_name $existing
        }
    } else {
        ^ln -s $existing $link_name | ignore
    }
}

# Explain the command using explainshell.com
export def explain [
    ...args
] {
    let command = $args | str join " " | str trim

    let url_arg = $command
        | str replace "%" "%25"
        | str replace " " "%20"
        | str replace "&" "%26"
        | str replace "|" "%7C"
        | str replace ";" "%3B"
        | str replace "(" "%28"
        | str replace ")" "%29"
        | str replace "{" "%7B"
        | str replace "}" "%7D"
        | str replace "[" "%5B"
        | str replace "]" "%5D"
        | str replace "<" "%3C"
        | str replace ">" "%3E"
        | str replace "#" "%23"
        | str replace "@" "%40"
        | str replace "$" "%24"
        | str replace "^" "%5E"
        | str replace "`" "%60"
        | str replace "\"" "%22"
        | str replace "'" "%27"
        | str replace "\\" "%5C"
        | str replace "/" "%2F"
        | str replace ":" "%3A"
        | str replace "=" "%3D"
        | str replace "?" "%3F"
        | str replace "!" "%21"
        | str replace "+" "%2B"
        | str replace "," "%2C"
        | str replace "." "%2E"
        | str replace "~" "%7E"

    let url = "https://explainshell.com/explain?cmd=" + $url_arg

    start $url
}

const dev_aliases = {
    "uni": "~/workspace/uni/",
    "nm4p": "~/workspace/uni/courses/nm4p/",
    "e-birb": "~/workspace/e-birb/",
    "e-light": "~/workspace/e-birb/repos/e-light"
}

def ws_aliases [] {
    $dev_aliases | items { |k, v|
        {
            value: $k
            description: $v
        }
    }
}

export def --env "ws" [ws: string@ws_aliases] {
    assert ($ws in $dev_aliases) $"no workspace alias for ($ws)"
    cd ($dev_aliases | get $ws)
}


# Make and change dir
#
# Alias to `mkdir $dir; cd $dir`
export def --env cdk [dir: path] {
    mkdir $dir
    cd $dir
}

export def friendly-path [
    path?: path      # The path to display (defaults to current directory)
    --force (-f)     # Allow non-existent paths (will check git from nearest existing parent)
]: nothing -> string {
    # Use provided path or current directory
    let target_path = if ($path | is-empty) {
        $env.PWD
    } else {
        $path | path expand
    }

    # Find the first existing directory (for git checks)
    let existing_dir = if ($target_path | path exists) {
        if ($target_path | path type) == "dir" {
            $target_path
        } else {
            $target_path | path dirname
        }
    } else if $force {
        # Recursively find the first existing parent directory
        mut check_path = $target_path | path dirname
        while not ($check_path | path exists) and ($check_path != "/" and $check_path != "~") {
            $check_path = ($check_path | path dirname)
        }
        if ($check_path | path exists) {
            $check_path
        } else {
            error make {msg: $"No existing parent directory found for: ($target_path)"}
        }
    } else {
        error make {msg: $"Path does not exist: ($target_path)"}
    }

    # Convert to home-relative path
    let dir = $target_path | relative_to_home

    # Check if we're in a git repo by running git in the existing directory
    let branch_response = (do --ignore-errors {
        cd $existing_dir
        ^git branch --show-current
    } | complete)
    
    if $branch_response.exit_code == 0 {
        # We're in a git repo
        let branch_lines = $branch_response.stdout | str trim | lines
        let branch = if ($branch_lines | length) == 0 {
            # Detached HEAD - use short commit hash
            let hash_response = (do --ignore-errors { 
                cd $existing_dir
                ^git rev-parse --short HEAD 
            } | complete)
            if $hash_response.exit_code == 0 {
                $"#($hash_response.stdout | str trim)"
            } else {
                "unknown"
            }
        } else {
            $branch_lines.0
        }
        
        # Get repo root and build the path
        let repo_root_response = (do --ignore-errors { 
            cd $existing_dir
            ^git rev-parse --show-toplevel 
        } | complete)
        
        if $repo_root_response.exit_code != 0 {
            # Shouldn't happen if we got a branch, but fallback to simple path
            return $dir
        }
        
        let repo_root_abs = $repo_root_response.stdout | str trim
        let repo_root = $repo_root_abs | relative_to_home
        let repo_parent = $repo_root | path dirname
        let repo_name = $repo_root_abs | path basename
        
        let path_relative_to_repo = match ($target_path | path relative-to $repo_root_abs) {
            "" => "",
            $relative => $"(char path_sep)($relative)"
        }
        
        # Build the friendly path: ~/parent/repo(branch)/subpath
        $"($repo_parent)(char path_sep)($repo_name)\(($branch)\)($path_relative_to_repo)"
    } else {
        # Not in a git repo, just return the home-relative path
        $dir
    }
}