resource "aws_iam_user" "admin-user" {
    name = "greg-tf"
    tags = {
      Description = "Technical Team Leader"
    }
}


resource "aws_iam_policy" "adminUser" {
    name = "AdminUsers"
    policy = <<EOF
      {
         "Version": "2012-10-17",
         "Statement": [
             {
                 "Effect": "Allow",
                 "Action": "*",
                 "Resource": "*"
             }
         ]
      }
      EOF
}

resource "aws_iam_user_policy_attachment" "lucy-admin-access" {
    user = aws_iam_user.admin-user.name
    policy_arn = aws_iam_policy.adminUser.arn
}



resource "aws_s3_bucket" "example_bucket" {
  bucket = "example-greg-cli-bucket" # Replace with your desired bucket name
  acl    = "private"

  tags = {
    Name        = "example-greg-cli-bucket"
    Environment = "Development"
  }
}

# Upload a File to the S3 Bucket
resource "aws_s3_object" "example_file" {
  bucket = aws_s3_bucket.example_bucket.id
  key    = "example.txt" # File name in S3
  source = "/tmp/example.txt" # Local file to upload
  acl    = "private"
}
