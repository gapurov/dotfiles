jq -r '.dependencies | to_entries | .[] | .key + "@" + .value '  package.json | \
while read -r key; do
    npm install -g $key
done 