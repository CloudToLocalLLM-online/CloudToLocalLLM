$ErrorActionPreference = "Stop"

$ClusterName = "cloudtolocalllm-eks"
$Region = "us-east-1"
$NodeGroupName = "cloudtolocalllm-eks-node-group"
$NodeRoleArn = "arn:aws:iam::422017356244:role/cloudtolocalllm-eks-node-role"
$Subnets = "subnet-029797aeb6cd6d69c", "subnet-04c42b1dbf2649b38"

Write-Host "Waiting for cluster $ClusterName to be active..."
aws eks wait cluster-active --name $ClusterName --region $Region
Write-Host "Cluster is active."

Write-Host "Creating node group $NodeGroupName..."
aws eks create-nodegroup `
    --cluster-name $ClusterName `
    --nodegroup-name $NodeGroupName `
    --scaling-config minSize=2,maxSize=3,desiredSize=2 `
    --subnets $Subnets `
    --node-role $NodeRoleArn `
    --instance-types t3.small `
    --region $Region

Write-Host "Waiting for node group to be active..."
aws eks wait nodegroup-active --cluster-name $ClusterName --nodegroup-name $NodeGroupName --region $Region
Write-Host "Node group is active."

Write-Host "Updating kubeconfig..."
aws eks update-kubeconfig --name $ClusterName --region $Region
Write-Host "Done."
