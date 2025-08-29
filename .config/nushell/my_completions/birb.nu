

def "nu-complete birb-task list formats" [] {
    [json yaml]
}

export extern "birb-task list" [
    --format(-f): string@"nu-complete birb-task list formats" # output format
] {
    
}