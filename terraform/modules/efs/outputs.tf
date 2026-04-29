output "efs_id"              { value = aws_efs_file_system.db.id }
output "access_point_id"    { value = aws_efs_access_point.db.id }
output "mount_target_ids"   { value = aws_efs_mount_target.db[*].id }
