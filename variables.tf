
variable "ingress_ports" {
  description = "The list of ingress ports to allow"
  type        = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
  }))
  default = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
    }
  ]
}

 variable "bastion_type" {
      description = "The ec2 type for development with a bastion"
      type = string
      default = "t2.micro"
 }
 
  variable "bastion_ami" {
     description = "The ami for development with a bastion"
     type = string
     default = "ami-0440d3b780d96b29d"
 }