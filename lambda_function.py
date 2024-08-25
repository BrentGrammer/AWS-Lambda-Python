# make your dependencies added available in the system path (we created a libs folder and installed them there)
import sys
sys.path.append('libs')

import pandas as pd
import requests


def handler(event, context):
    # test pandas lib usage
    myData = {'col1': [1,2], 'col2': [3,4]}
    df = pd.DataFrame(data=myData)
    print('Pandas DF: ')
    print(df)

    res = requests.get('https://google.com')
    if (res.text):
        print('Got a response from requests call - requests lib works')

    print(f'{event=}')
    
    return {"statusCode": 200, "body": "hello world"}