# Recreated early QuantQuest strategy experiment
# This is not an original file from 9th/10th grade.
# It was recreated later from my memory of the simple strategy ideas I used then,
# with AI assistance while preparing my portfolio.

prices = [100, 101, 102, 104, 106]

start_price = prices[0]
current_price = prices[-1]
change = (current_price - start_price) / start_price

print("Start price:", start_price)
print("Current price:", current_price)
print("Change:", change)

if change > 0.02:
    print("BUY")
elif change < -0.02:
    print("SELL")
else:
    print("HOLD")
