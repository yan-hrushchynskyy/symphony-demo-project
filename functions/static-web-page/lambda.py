import json

def lambda_handler(event, context):
    html_content = """
    <html>
    <head>
        <title>Static Web Page</title>
        <meta charset="UTF-8">
        <style>
            body {
                font-family: Arial, sans-serif;
                background-color: #f4f4f4;
                text-align: center;
                padding-top: 50px;
            }
            h1 {
                color: #333;
            }
        </style>
    </head>
    <body>
        <h1>Hello Symphonians!</h1>
        <p>This is a simple static page served by AWS Lambda.</p>
        <p>Продам Пежо 206+ по ціні макбука. За деталями звертайтесь в ПП</p>
    </body>
    </html>
    """
    
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'text/html; charset=utf-8'  # Ensure utf-8 encoding
        },
        'body': html_content
    }