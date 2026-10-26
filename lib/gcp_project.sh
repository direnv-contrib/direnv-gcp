# use_gcp_project: select the Google Cloud project for gcloud and the client libraries
#
#   use_gcp_project my-project    sets CLOUDSDK_CORE_PROJECT (gcloud) and GOOGLE_CLOUD_PROJECT
#                                 (client libraries), overriding the active gcloud configuration

use_gcp_project() {
  if [[ $# -ne 1 || -z $1 ]]; then
    log_error "use_gcp_project: usage: use_gcp_project project-id"
    return 1
  fi

  export CLOUDSDK_CORE_PROJECT=$1
  export GOOGLE_CLOUD_PROJECT=$1
  log_status "use_gcp_project: $1"
}
