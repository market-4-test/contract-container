#!/bin/sh

set -e

execute_with_error_handling() {
    if ! "$@"; then
        exit 1
    fi
}

create_release() {
    local repo_url=$1
    local version=$2

    if [[ $repo_url != https://* ]]; then
        repo_url="https://${repo_url}"
    fi

    # Извлечение имени владельца и репозитория из URL
    local repo_owner=$(echo ${repo_url} | sed -E 's|https://github.com/||' | cut -d'/' -f1)
    local repo_name=$(echo ${repo_url} | sed -E 's|https://github.com/||' | cut -d'/' -f2 | sed 's/\.git$//')

    echo "Creating release for ${repo_owner}/${repo_name} with version ${version}"

    local response=$(curl -X POST \
      -H "Authorization: token ${REPO_PACKAGE_TOKEN}" \
      -H "Accept: application/vnd.github.v3+json" \
      -w "\n%{http_code}" \
      https://api.github.com/repos/${repo_owner}/${repo_name}/releases \
      -d '{
        "tag_name": "'"${version}"'",
        "name": "Release '"${version}"'",
        "body": "Release '"${version}"' (from proto '"${version}"')",
        "draft": false,
        "prerelease": false
      }')

    local body=$(echo "$response" | sed '$d')
    local status=$(echo "$response" | tail -n1)

    echo "Response body: $body"
    echo "Status code: $status"

    if [ "$status" != "201" ]; then
        echo "Failed to create release. Status code: $status"
        exit 1
    fi
}

# Компиляция Proto файлов
execute_with_error_handling mkdir -p go_out
execute_with_error_handling protoc -I src --go_out=go_out --go_opt=paths=source_relative --go-grpc_out=go_out --go-grpc_opt=paths=source_relative src/*/*.proto

if [ -z "$EXCLUDE_TS" ]; then
    execute_with_error_handling mkdir -p ts_out
    execute_with_error_handling protoc -I src --plugin=protoc-gen-ts=/usr/local/bin/protoc-gen-ts --ts_out=ts_out src/*/*.proto
fi

# Push Go files
execute_with_error_handling git clone https://${REPO_PACKAGE_TOKEN}@${GO_REPO} go-repo
execute_with_error_handling cp -R go_out/* go-repo/
cd go-repo
execute_with_error_handling go mod tidy
execute_with_error_handling git config user.name github-actions
execute_with_error_handling git config user.email github-actions@github.com
execute_with_error_handling git add .
execute_with_error_handling git commit -m "Update from proto repo ${PARENT_VERSION}" --allow-empty
execute_with_error_handling git tag -a ${PARENT_VERSION} -m "Release ${PARENT_VERSION} (from proto ${PARENT_VERSION})"
execute_with_error_handling git push origin main --tags
create_release ${GO_REPO} ${PARENT_VERSION}
cd ..

# Push TypeScript files
if [ -z "$EXCLUDE_TS" ]; then
  execute_with_error_handling git clone https://${REPO_PACKAGE_TOKEN}@${TS_REPO} ts-repo
  execute_with_error_handling rm -rf ts-repo/src/*
  execute_with_error_handling cp -R ts_out/* ts-repo/src
  cd ts-repo
  execute_with_error_handling git config user.name github-actions
  execute_with_error_handling git config user.email github-actions@github.com
  execute_with_error_handling npm version ${PARENT_VERSION} --no-git-tag-version
  execute_with_error_handling git add .
  execute_with_error_handling git commit -m "Update from proto repo ${PARENT_VERSION}" --allow-empty
  execute_with_error_handling git tag -a ${PARENT_VERSION} -m "Release ${PARENT_VERSION} (from proto ${PARENT_VERSION})"
  execute_with_error_handling git push origin main --tags
  create_release ${TS_REPO} ${PARENT_VERSION}
  cd ..
fi