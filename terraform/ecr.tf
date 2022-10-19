# Create ECR repository
resource "aws_ecr_repository" "test_service" {
  name = "wolke7-petclinic"
  force_delete = "true"
}

# Build Docker image and push to ECR from folder: ./example-service-directory
module "ecr_docker_build" {
  source = "github.com/onnimonni/terraform-ecr-docker-build-module"

  # Absolute path into the service which needs to be build
  dockerfile_folder = "${path.module}/../../petclinic"

  # Tag for the builded Docker image (Defaults to 'latest')
  docker_image_tag = "development"
  
  # The region which we will log into with aws-cli
  aws_region = "eu-central-1"

  # ECR repository where we can push
  ecr_repository_url = "${aws_ecr_repository.test_service.repository_url}"
}