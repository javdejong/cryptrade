import pandas as pd
import datetime as dt
import json

df = pd.read_csv('btceUSD.csv', names=['time','price','volume'])
df.time = pd.to_datetime(df.time, unit='s')
df.set_index('time', inplace=True)

# slicing:
start = df.index.searchsorted(dt.datetime(2014,1,1))
df = df.ix[start:]

# 
price = df.resample('2h', how={'price': 'ohlc'})
vol   = df.resample('2h', how={'volume': 'sum'})

# Forward the close value of the previous tick for OHLC 
price.columns = price.columns.get_level_values(1)
price2 = price.fillna(method='ffill')
price = price.fillna(value={'open': price2.close, 'high': price2.close, 'low': price2.close, 'close': price2.close})

# Volume is 0.0 for NaNs
vol = vol.fillna(value=0.0)

# Concatenate volume and ohlc into ohlcv
tot = pd.concat([price, vol], axis=1)

# Rename the time field
tot = tot.reset_index()
tot = tot.rename(columns={'time': 'at'})

# Output to json
parsed = json.loads(tot.to_json(orient='records'))

with open('2014.json', 'w') as outfile:
    outfile.write(json.dumps(parsed, indent=4, sort_keys=True))
    outfile.close()



