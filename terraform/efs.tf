# EFS gives the SQLite file a persistent home that survives ECS task
# replacements and rollbacks.  Without this, every new container starts with an
# empty database.  Only the backend service mounts EFS; the frontend has no
# need for persistent storage.

resource "aws_efs_file_system" "db" {
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    # Move files not accessed for 30 days to infrequent-access storage to save cost
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = merge(local.common_tags, { Name = "todo-${local.env}-db" })
}

# One EFS mount target per private subnet so any Fargate task can reach it
# regardless of which AZ it lands in.
resource "aws_efs_mount_target" "db" {
  count           = length(aws_subnet.private)
  file_system_id  = aws_efs_file_system.db.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs.id]
}

# Access point pins the mount to /data inside the EFS volume and enforces a
# POSIX UID/GID so the non-root container user can write the SQLite file.
resource "aws_efs_access_point" "db" {
  file_system_id = aws_efs_file_system.db.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/data"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }

  tags = merge(local.common_tags, { Name = "todo-${local.env}-db-ap" })
}
