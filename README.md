# GitHub Action to build an OVA using the On-Prem Meta API

This action launches an OVA build on an [On-Prem Meta](https://on-premises.com) appliance. It registers the `builddate`, build `status`, and the list of available `downloads` URLs.

![On-Prem Meta](https://user-images.githubusercontent.com/153401/69914371-7b26fc80-143b-11ea-8b87-e76ab75a8d0a.jpg)

## About this Action

This GitHub Action is written in [CoffeeScript](index.coffee) and builds on the [on-prem-meta NodeJS module](http://github.com/on-prem/on-prem-meta-node), which provides functions to easily manage the _Meta_ or [Admin API](https://github.com/on-prem/jidoteki-admin-api).

1. [Getting started](#getting-started)
2. [Secrets](#secrets-required)
3. [Environment variables](#environment-variables-optional)
4. [Inputs](#inputs)
5. [Outputs](#outputs)
6. [Examples](#examples)
7. [Notes](#notes)
8. [Build](#build)
9. [License](#license)

## Getting started

* Obtain a license for the [On-Prem Meta OVA](https://on-premises.com), and ensure it's setup and [accessible remotely by GitHub](https://help.github.com/en/github/authenticating-to-github/about-githubs-ip-addresses)
* Create a workflow in the GitHub repository containing your appliance settings (see [examples](#Examples) below)

### Secrets (required)

[Register some secrets](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/creating-and-using-encrypted-secrets) for this Action to interact with your On-Prem Meta appliance. These _secrets_ **must** be set as environment variables in your workflow.

* `ON_PREM_META_HOST`: the hostname and port of your appliance (ex: `meta.yourdomain.com:443`)
* `ON_PREM_META_APITOKEN`: the API token to launch a build on your appliance (ex: `yourtoken`)

### Environment variables (optional)

* `ON_PREM_META_INSECURE`: If you're using a self-signed certificate, set to `true`. Default: `false` to always verify certificates

### Inputs

All build parameters for the On-Prem Meta API's `POST /builds` endpoint are available as an _Input_ to this action.

#### `app`

**(required)** The location of your application (ex: `/my/path/app.tcz`). **Note: This is not the file contents, just the path to the file**

#### `repo_name`

**(required)**: Git repository containing appliance settings

#### `ova_type`

**(required)**: The type of OVA to build (ex: server)

#### `version`

**(optional)**: The OVA's OS version. Default: `1.0.0` or `auto-increments`

#### `friendly_name`

**(optional)**: A friendly name for display purposes only. Default: `v1.0.0-<commit>` or `auto-increments`

#### `build_type`

**(optional)**: `1` for OVA, `2` for Diff, `3` for OVA+Diff, `4` for Bundle, `5` for OVA+Bundle, `8` for Full, `9` for OVA+Full, `15` for OVA+Diff+Bundle+Full. Default: `15`

#### `ova_source`

**(optional)**: The build ID (builddate) of a previous build. Required if `build_type` is `2`, `3`, `4`, `5`, or `15`. Default: `last successful released build` if `build_type > 1`

#### `commit`

**(optional)**: The Git branch/tag/commit ID to build from. Default: `HEAD`

#### `bundle_sources`

**(optional)**: A comma-separated list of build IDs for creating a bundle update package. Required if `build_type` is `4`, `5`, or `15`. Default: `same as ova_source`

#### `notes`

**(optional)**: A free-form text field to store notes related the build. Only accepts `abcdefghijklmnopqrstuvwxyz0123456789-_.,#!*[]&/() \n\"\\:`

#### `node_source`

**(optional)**: The build ID (builddate) of another appliance built with `build_type 8, 9, or 15`, to be included in an OVA or Update.

#### `app_sha256`

**(optional)**: The SHA256 checksum hash of the app file. If provided, a validation will ensure the uploaded app's checksum matches.

#### `export_disks`

**(optional)**: A comma-separated list of disk types to export. Only accepts `raw`, `qcow2`, `vhd` when `build_type` is `1`, `3`, `5`, `9`, or `15`.

#### `ova_files`

**(optional)**: A comma-separated list of OVAs to be built (ex: small,large). Default: `all`.

### Outputs

#### `builddate`

The builddate which can be used to perform additional API calls (ex: `1574834281.966265128`)

#### `status`

The status of the build once it completes (ex: `success` or `failed`)

#### `downloads`

The list of download URLs for a build (ex: `https://meta.yourdomain.com:443/downloads/build-1574834281.966265128/your-appliance-v1.2.3-release.ova`)

## Examples

The example below will generate an OVA with a dummy `app.tcz`. This workflow can be modified to perform many more tasks before and after building the OVA, and it can be triggered on other events such as `pull_request`. See [GitHub Actions documentation](https://help.github.com/en/actions/automating-your-workflow-with-github-actions)

`.github/workflows/main.yml`

```yaml
name: OVA
on: [push]
jobs:
  build:
    # timeout after 2.5 hours
    timeout-minutes: 180
    runs-on: ubuntu-latest
    steps:
    # checkout the repo's code (appliance settings)
    - name: Checkout the repo
      uses: actions/checkout@v1
    # generate a dummy app.tcz (can be created in another job or downloaded from an external URL)
    - name: Generate an app.tcz
      run: |
        cd /tmp
        mkdir myapp
        echo "test app" > myapp/testfile.txt
        mksquashfs myapp app.tcz -b 4096
    # build the OVA with some example parameters
    - name: Use On-Prem Meta to build an OVA
      uses: on-prem/action-build-ova@v1
      id: buildova
      with:
        app: '/tmp/app.tcz'
        repo_name: ${{ github.event.repository.name }}
        ova_type: 'appliance'
        commit: ${{ github.sha }}
        build_type: 9
        export_disks: 'raw,qcow2,vhd'
      # set the required environment variables
      env:
        ON_PREM_META_HOST: ${{ secrets.ON_PREM_META_HOST }}
        ON_PREM_META_APITOKEN: ${{ secrets.ON_PREM_META_APITOKEN }}
    # output the results
    - name: "Output the builddate, status, downloads"
      run: |
        echo "Building OVA: ${{ steps.buildova.outputs.builddate }}"
        echo "OVA Status: ${{ steps.buildova.outputs.status }}"
        echo "OVA Downloads: ${{ steps.buildova.outputs.downloads }}"
```

## Notes

* This Action performs **no input validation**, since the On-Prem Meta API validates all parameters. It is still necessary to be careful which values you define in your YAML workflow
* It is recommended to specify [timeout-minutes: 180](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/workflow-syntax-for-github-actions#jobsjob_idtimeout-minutes) in the workflow, to prevent polling for too long
* **(TODO)** A canceled workflow run will not cancel a running build. This will be fixed in a future version
* All failures, such as API errors, 404s, timeouts, failed builds, etc, will return a `conclusion: failure` in the [Checks API](https://developer.github.com/v3/checks/)
* A successful build will return a `conclusion: success` in the [Checks API](https://developer.github.com/v3/checks/)

## Build

To build this action:

* Install `NodeJS v12`
* Install the dev dependencies with `npm install`
* Generate the `dist/index.js` with `npm run build`

# License

[MPL-2.0 License](LICENSE)

Copyright (c) 2019 Alexander Williams, Unscramble <license@unscramble.jp>
