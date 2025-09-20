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
