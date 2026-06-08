# To fetch the git tag for each AWS image.
function aws_images
  set FAMILY "wlw-1__visable-dev__sales-tool-frontend__v1__web_internal"

  for arn in (aws ecs list-task-definitions --family-prefix $FAMILY --sort DESC --query 'taskDefinitionArns[:3]' --output json | jq -r '.[]')
      set IMAGE (aws ecs describe-task-definition --task-definition $arn --query 'taskDefinition.containerDefinitions[0].image' --output text 2>/dev/null)
      set REV (echo $arn | sed 's/.*://')
      set SHA (echo $IMAGE | sed 's/.*main-//' | sed 's/[^a-f0-9].*$//')
      echo "Revision: $REV | Image: $IMAGE | SHA: $SHA"
  end
end
