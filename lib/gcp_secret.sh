# use_gcp_secret: load Google Secret Manager secrets into the environment
#
#   use_gcp_secret db-creds         JSON secret: one variable per key, uppercased
#                                   plain secret: one variable named after the secret id
#   use_gcp_secret db-creds@3       a specific version, the default is latest
#   use_gcp_secret DB_URL=db-url    the raw secret string with an explicit variable name
#
# The project comes from CLOUDSDK_CORE_PROJECT or the active gcloud configuration,
# see use_gcp_project.

# $1: explicit variable name (optional), $2: secret id
# stdin: the secret payload
# stdout: NUL-delimited name/value pairs
_gcp_secret_emit() {
  jq -Rsj --arg name "$1" --arg id "$2" '
    def envname: ascii_upcase | gsub("[^A-Z0-9_]"; "_");
    . as $s
    | if $name != "" then $name, "\u0000", $s, "\u0000"
      else ($s | try fromjson catch null) as $j
        | if ($j | type) == "object" then
            $j | to_entries[]
            | (.key | envname), "\u0000",
              (.value | if type == "string" then . else tojson end), "\u0000"
          else ($id | envname), "\u0000", $s, "\u0000"
          end
      end'
}

use_gcp_secret() {
  if [[ $# -eq 0 ]]; then
    log_error "use_gcp_secret: usage: use_gcp_secret [NAME=]secret-id[@version] ..."
    return 1
  fi
  has gcloud || { log_error "use_gcp_secret: gcloud not found"; return 1; }
  has jq || { log_error "use_gcp_secret: jq not found"; return 1; }

  local arg name secret_id version payload key value count=0
  for arg in "$@"; do
    name="" secret_id=$arg version=latest
    if [[ $arg == *=* ]]; then
      name=${arg%%=*}
      secret_id=${arg#*=}
    fi
    if [[ $secret_id == *@* ]]; then
      version=${secret_id#*@}
      secret_id=${secret_id%%@*}
    fi
    if [[ -z $secret_id || -z $version ]]; then
      log_error "use_gcp_secret: invalid secret '$arg'"
      return 1
    fi

    payload=$(gcloud secrets versions access "$version" --secret="$secret_id") || {
      log_error "use_gcp_secret: failed to read $secret_id"
      return 1
    }

    while IFS= read -r -d '' key && IFS= read -r -d '' value; do
      if [[ ! $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        log_error "use_gcp_secret: invalid variable name '$key'"
        return 1
      fi
      export "$key=$value"
      ((count++))
    done < <(printf '%s' "$payload" | _gcp_secret_emit "$name" "$secret_id")
  done

  log_status "use_gcp_secret: loaded $count variable(s)"
}
