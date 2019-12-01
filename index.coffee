# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2019 Alexander Williams, Unscramble <license@unscramble.jp>

# Main required modules
core      = require '@actions/core'
exec      = require '@actions/exec'
onprem    = require '@on-prem/on-prem-meta'

init = () ->
  try
    # Get input variables
    app_path     =    await core.getInput('app',            { required: true })
    query_params =
      repo_name:      await core.getInput('repo_name',      { required: true })
      ova_type:       await core.getInput('ova_type',       { required: true })
      version:        await core.getInput('version',        { required: false })
      friendly_name:  await core.getInput('friendly_name',  { required: false })
      build_type:     await core.getInput('build_type',     { required: false })
      ova_source:     await core.getInput('ova_source',     { required: false })
      commit:         await core.getInput('commit',         { required: false })
      bundle_sources: await core.getInput('bundle_sources', { required: false })
      notes:          await core.getInput('notes',          { required: false })
      node_source:    await core.getInput('node_source',    { required: false })
      app_sha256:     await core.getInput('app_sha256',     { required: false })
      export_disks:   await core.getInput('export_disks',   { required: false })
      ova_files:      await core.getInput('ova_files',      { required: false })

    # Make API call to build the OVA
    onprem.buildOVA app_path, query_params, (err, res, callback) =>
      if err
        console.error "ERROR (buildOVA):", err
        await core.setFailed "Action failed with error #{err['Status']} and message: #{err['Error-Message']}"
        process.exit 1
      else
        # The API call succeded and we got a builddate
        builddate = res
        console.log "builddate:", builddate
        await core.setOutput 'builddate', builddate

        # Start polling the status of the OVA build
        onprem.pollStatus builddate, undefined, (err, res) =>
          if err
            console.error "ERROR (pollStatus):", err
            await core.setFailed "Action failed with error #{err['Status']} and message: #{err['Error-Message']}"
            process.exit 1
          else
            # The status was returned as 'success' or 'failed'
            status = res

            if status is 'success'
              await core.setOutput 'status', status

              # Try to get the list of download URLs
              onprem.getDownloads builddate, (err, res) =>
                if err
                  console.error "ERROR (getDownloads):", err
                  await core.setFailed "Action failed with error #{err['Status']} and message: #{err['Error-Message']}"
                  process.exit 1
                else
                  # The list was obtained and all is good
                  downloads = res
                  console.log "downloads:", downloads
                  await core.setOutput 'downloads', downloads
                  process.exit 0

            else if status is 'failed'
              # All the API calls worked, but the build failed for some reason
              await core.setOutput 'status', status
              await core.setFailed "Build failed with status #{status}"
              process.exit 1

      await return

  catch error
    await core.setFailed error.message

init()
