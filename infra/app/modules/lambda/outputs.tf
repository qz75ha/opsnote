output "create_fn_invoke_arn" { value = aws_lambda_function.create.invoke_arn }
output "list_fn_invoke_arn" { value = aws_lambda_function.list.invoke_arn }
output "get_fn_invoke_arn" { value = aws_lambda_function.get.invoke_arn }

output "create_fn_name" { value = aws_lambda_function.create.function_name }
output "list_fn_name" { value = aws_lambda_function.list.function_name }
output "get_fn_name" { value = aws_lambda_function.get.function_name }
