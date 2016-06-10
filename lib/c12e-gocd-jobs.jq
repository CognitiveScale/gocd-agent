def pipeline_update:
  {
    "name": .name,
    "template": "c12e-ci",
    "label_template": (.name + "-${COUNT}"),
    "enable_pipeline_locking": false,
    "materials": [
      {
        "type": "git",
        "attributes": {
          "name": .name,
          "url": ("git@github.com:" + .git_org + "/" + .name + ".git"),
          "branch": .git_branch,
          "auto_update": true,
          "shallow_clone": true
        }
      }
    ]
  };


def pipeline_create:
  {
    "group": .group,
    "pipeline": pipeline_update
  };


def defaults:
  {
    "git_org": "CognitiveScale",
    "git_branch": "dev",
  } + .;


def validate(required_key):
  if has(required_key)
  then .
  else error("missing key: " + required_key)
  end;


def validate_update:
  validate("name")
  | validate("git_org")
  | validate("git_branch");


def validate_create:
  validate_update | validate("group");


defaults |
  if .create
  then validate_create | pipeline_create
  else validate_update | pipeline_update
  end
