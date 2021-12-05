set -e
#set -x

downstream_workflow_repo=$1
downstream_workflow=$2
downstream_workflow_branch=$3
PAT=$4
GITHUB_RUN_ID=$5
GITHUB_REPO=$6
INPUT_VARIABLES=$7

downstream_workflow_checker() {
  PAT=$1
  ID=$2
  downstream_workflow_repo=$3


  DATE=$(date +"%Y-%m-%dT%H:%M:%SZ")
  DATE_RANGE=$(date -d "$DATE -5 min" +'%Y-%m-%dT%H:%M:%SZ')

  echo "Downstream job triggered by current job :"

  i=0
  while [[ -z $JOB_URL ]]; do
      sleep 5
      URLS=$(curl -s -X GET -H "Accept: application/vnd.github.v3+json" -H "Authorization: token $PAT"  "https://api.github.com/repos/${downstream_workflow_repo}/actions/runs?created=>$DATE_RANGE" | jq -r ."workflow_runs[].jobs_url")
      for URL in $URLS; do
           curl -s -X GET -H "Accept: application/vnd.github.v3+json" -H "Authorization: token $PAT"  "$URL" > tmp_file.json
           JOB_URL=$(cat tmp_file.json | jq -r ."jobs[].steps[].name" | grep $ID >> /dev/null && cat tmp_file.json  | jq -r ."jobs[].run_url" | head -n1 | sed 's/api.//' | sed 's/repos\///g' || true)
           [[ -n $JOB_URL ]] && echo "$JOB_URL" | tee job_url && break
      done

      ((i+=1))
      if [[ $i -eq 5 ]]; then
          echo "Cannot determine DOWNSTREAM job!!! Exiting finding in loop...." && break #maybe exit?
      fi
  done
}

downstream_workflow_identifier=$(echo $RANDOM | md5sum | head -c 20)
upstream_workflow_identifier=$GITHUB_RUN_ID
identifier="identifiers-$GITHUB_REPO-$downstream_workflow_identifier-$upstream_workflow_identifier"

echo "{\"ref\":\"${downstream_workflow_branch}\", \"inputs\": { ${INPUT_VARIABLES}, \"id\":\"${identifier}\"}}" > data_payload.json
# DEBUG LOG cat data_payload.json

curl \
  -s -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token ${PAT}" \
  https://api.github.com/repos/${downstream_workflow_repo}/actions/workflows/${downstream_workflow}/dispatches \
  -d @data_payload.json

downstream_workflow_checker ${PAT} $identifier $downstream_workflow_repo
