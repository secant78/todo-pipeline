resource "aws_efs_file_system" "db" {
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  tags = merge(var.common_tags, { Name = "todo-${var.env}-db" })
}

resource "aws_efs_mount_target" "db" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.db.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [var.efs_sg_id]
}

resource "aws_efs_access_point" "db" {
  file_system_id = aws_efs_file_system.db.id
  posix_user { uid = 1000; gid = 1000 }
  root_directory {
    path = "/data"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }
  tags = merge(var.common_tags, { Name = "todo-${var.env}-db-ap" })
}
