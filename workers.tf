resource "aws_autoscaling_group" "workers" {
  name_prefix          = "${var.cluster_name}-${lookup(var.worker_groups[count.index], "name", count.index)}"
  desired_capacity     = "${lookup(var.worker_groups[count.index], "asg_desired_capacity", lookup(var.workers_group_defaults, "asg_desired_capacity"))}"
  max_size             = "${lookup(var.worker_groups[count.index], "asg_max_size",lookup(var.workers_group_defaults, "asg_max_size"))}"
  min_size             = "${lookup(var.worker_groups[count.index], "asg_min_size",lookup(var.workers_group_defaults, "asg_min_size"))}"
  launch_configuration = "${element(aws_launch_configuration.workers.*.id, count.index)}"
  vpc_zone_identifier  = ["${var.subnets}"]
  count                = "${length(var.worker_groups)}"

  tags = ["${concat(
    list(
      map("key", "Name", "value", "${var.cluster_name}-${lookup(var.worker_groups[count.index], "name", count.index)}-eks_asg", "propagate_at_launch", true),
      map("key", "kubernetes.io/cluster/${var.cluster_name}", "value", "owned", "propagate_at_launch", true),
    ),
    local.asg_tags)
  }"]
}

resource "aws_launch_configuration" "workers" {
  name_prefix                 = "${var.cluster_name}-${lookup(var.worker_groups[count.index], "name", count.index)}"
  associate_public_ip_address = "${lookup(var.worker_groups[count.index], "public_ip", lookup(var.workers_group_defaults, "public_ip"))}"
  security_groups             = ["sg-1f3be757"]
  iam_instance_profile        = "arn:aws:iam::550522744793:instance-profile/DevopsAdminRole"
  image_id                    = "ami-43a15f3e"
  instance_type               = "${lookup(var.worker_groups[count.index], "instance_type", lookup(var.workers_group_defaults, "instance_type"))}"
  key_name                    = "NavitasDevOps"
  user_data_base64            = "${base64encode(element(data.template_file.userdata.*.rendered, count.index))}"
  ebs_optimized               = "${lookup(var.worker_groups[count.index], "ebs_optimized", lookup(local.ebs_optimized, lookup(var.worker_groups[count.index], "instance_type", lookup(var.workers_group_defaults, "instance_type")), false))}"
  count                       = "${length(var.worker_groups)}"

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    delete_on_termination = true
  }
}

resource "aws_iam_role" "workers" {
  name_prefix        = "${var.cluster_name}"
  assume_role_policy = "${data.aws_iam_policy_document.workers_assume_role_policy.json}"
}

resource "aws_iam_instance_profile" "workers" {
  name_prefix = "${var.cluster_name}"
  role        = "arn:aws:iam::550522744793:role/DevopsAdminRole"
}

resource "aws_iam_role_policy_attachment" "workers_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "arn:aws:iam::550522744793:role/DevopsAdminRole"
}

resource "aws_iam_role_policy_attachment" "workers_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "arn:aws:iam::550522744793:role/DevopsAdminRole"
}

resource "aws_iam_role_policy_attachment" "workers_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "arn:aws:iam::550522744793:role/DevopsAdminRole"
}

resource "null_resource" "tags_as_list_of_maps" {
  count = "${length(keys(var.tags))}"

  triggers = "${map(
    "key", "${element(keys(var.tags), count.index)}",
    "value", "${element(values(var.tags), count.index)}",
    "propagate_at_launch", "true"
  )}"
}
