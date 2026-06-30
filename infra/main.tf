module "vpc" {
  source      = "./modules/vpc"
  environment = var.environment
}

module "ecr" {
  source = "./modules/ecr"
}

module "acm" {
  source                    = "./modules/acm"
  project_name              = "gatus"
  domain_name               = var.domain_name
  subdomain                 = var.subdomain
  subject_alternative_names = [var.domain_name]

}

module "alb" {
  source            = "./modules/alb"
  project_name      = "gatus"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = module.acm.certificate_arn
  domain_name       = var.domain_name
  subdomain         = var.subdomain
}

module "ecs" {
  source                = "./modules/ecs"
  project_name          = "gatus"
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  alb_security_group_id = module.alb.alb_security_group_id
  target_group_arn      = module.alb.target_group_arn
  ecr_image_url         = "${module.ecr.repository_url}:latest"
}

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.subdomain
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}
