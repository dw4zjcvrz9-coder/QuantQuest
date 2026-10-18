# Recreated early QuantQuest strategy experiment
# This is not an original file from 9th/10th grade.
# It was recreated later from my memory of the simple strategy ideas I used then,
# with AI assistance while preparing my portfolio.

prices = [100, 101, 99, 100, 96]

average = sum(prices) / len(prices)
current_price = prices[-1]
difference = (current_price - average) / average

print("Average price:", average)
print("Current price:", current_price)
print("Difference from average:", difference)

if difference < -0.02:
    print("BUY")
elif difference > 0.02:
    print("SELL")
else:
    print("HOLD")
