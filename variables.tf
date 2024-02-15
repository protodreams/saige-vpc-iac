
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