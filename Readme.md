## git gerrit tools

These are some shell based tools that bridge some functionality from gerrit into git so you don't relly on the web interface of gerrit so much.

### tools

#### git verify
```bash
$ git verify [git rev-list arguments] [-- verification command ]
```

Interactivelly goes through each rev-list result running command. If the command is successfull marks the gerrit entry as verifyed (if it has been pushed) otherwise it stops and creates the ref "refs/verify/broken".

The default arguments will `--reverse <upstream>...<current branch>`. This will go through all commits that were not yet merged into the default upstream for the current branch in reverse order.

#### gerrit

Shortcut to the gerrit command line tools, those are usually accessible using ssh, but this command will examine git and if the current branch upstream is an ssh URL it will use that toi extrac the ssh parameters.

#### gerrit-approvals

Print all approvals, and reviewers, for the commit passed on the command line.

```bash
$ gerrit-approvals HEAD
Reviewer: Author <author@something.com>
Reviewer: Reviewer <reviewer@something.com>
Code-Review 2: Reviewer
SUBM 1: Author
Verified 1: Author
```

This command and all the commands that depend on it require (`jq`)[https://stedolan.github.io/jq/] to be installed on the current path.

#### git gerrit-tags

Add notes to all the commits in the range, passed in by using `git rev-list` arguments, with the approvals, as returned by gerrit-appovals, to the commits. This allows you to see all the approvals from commits while off line or without a round trip to the service.

#### git gerrit-clean-tags

Remove the notes added by the previous command.


