# generic-hpc-scripts

We are collecting here some generic scripts that contribute to `nemo-build`, `ectrans-build`, `ifsnemo-build` infrastructure and other similar projects based on `dbscripts` + `psubmit` combination.

Add this project as a submodule to your `dbscripts` + `psubmit` based build and run project.

```
$ git submodule add https://earth.bsc.es/gitlab/ces/hpc-for-es-team/generic-hpc-scripts.git scripts/generic
$ git submodule update --init --recursive
```

NOTE: for automated authorization on the gitlab server please use ~/.netrc file that contains your GitLab username and your personal access token for this gitlab server.

For the GitLab server of Earth Science department, user can make his own access token as follows.

- Go to the user profile `https://earth.bsc.es/gitlab/-/profile`
- In the leftmost column with some icons, find the "Access Tokens" pictogram. It should lead to the page `https://earth.bsc.es/gitlab/-/profile/personal_access_tokens`.
- Create your own token with an arbitrary name, reasonable expiration date and all the permissions set.
- Save this token in your scripts as a value of `DNB_GITLAB_ACCESS_TOKEN` environment variable (you may add this setting to your .bashrc on a target system). The `DNB_GITLAB_USERNAME` then must contain your gitlab username.
- Also save this information in the `$HOME/.netrc` file on the machines and nodes where you plan to perform downloads (please google the `.netrc` syntax).

