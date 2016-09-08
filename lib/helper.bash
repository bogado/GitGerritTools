#!/usr/bin/env bash

function upstream_remote() {
    local branch="${1:-$(git symbolic-ref HEAD)}"
    git for-each-ref "refs/heads/" --format="%(upstream:short)" | cut -d / -f 1
}

# Returns protocol, user, host and port on an array.
function splitURL() {
    local url=$1
    declare -ag $2="( $(echo $url | sed -E 's/^([[:alpha:]]+):\/\/(([[:print:]]+)@)?([^/:]*)(:([[:digit:]]+))?\/(.*)$/[0]="\1" [1]="\3" [2]="\4" [3]="\6" [4]="\7"/') )"
}

function split_remote() {
    local var=$1
    local remote=${2:-$(upstream_remote)}
    splitURL "$(git remote get-url $remote)" "$var"
}

function gerrit_url() {
    for remote in $(git remote); do git remote get-url $remote; done | grep ssh | sort | uniq
}

function gerrit() {
    splitURL $(gerrit_url) remote_url
    ssh -p ${remote_url[3]} ${remote_url[1]}@${remote_url[2]} gerrit "$@"
}

function git-foreach() {
    local branch="$(git symbolic-ref --short HEAD)"
    local upstream="$(git rev-parse '@{upstream}')"

    declare -a execute__
    declare -a on_success__
    declare -a on_error__

    local current="upstream"
    while [[ $# > 0 ]]; do
        local arg="$1"
        shift

        case "$arg" in
            --exec)
                current="exec"
                continue;;
            --on-success)
                current="success"
                continue;;
            --on-error)
                current="error"
                continue;;
        esac

        case "$current" in
            exec)
                execute__+=("$arg");;
            success)
                on_success__+=("$arg");;
            error)
                on_error__+=("$arg");;
            upstream)
                upstream="$arg"
                current="";;
        esac
    done

    (
        function cleanup() {
            git checkout $branch
        }
        trap cleanup EXIT

        cd $(git rev-parse --show-toplevel)
        for commit in $(git rev-list --reverse $upstream..$branch); do
            git checkout --detach $commit > /dev/null
            commit='"'$(git log -1 --pretty=format:%s | cut -b "1-70" )'"'
            msg "processing $commit"
            if "${execute__[@]}"; then
                "${on_success__[@]}";
            else
                "${on_error__[@]}";
                break;
            fi
        done
    )

}

function msg() {
    echo
    echo ================================================================================
    echo "$@"
    echo ================================================================================
    echo
}

function gerrit_approvals() {
    gerrit query --format=json --all-approvals "$@" | head -n 1 | jq -r '.patchSets[-1].approvals[] | .type + ":" + .value'
}
