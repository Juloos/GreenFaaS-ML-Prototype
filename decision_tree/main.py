from data import DATA

from sklearn.tree import DecisionTreeClassifier
from sklearn.model_selection import train_test_split
from random import randint

SCHEMA, TEXT, WATTS, MS = range(4)

step = 10000  # classes are intervals of size <step> watts
X = [(row[SCHEMA], row[TEXT]) for row in DATA]
Y = [int(row[WATTS] // step) for row in DATA]

print("X : " + str(X))
print("Y : " + str(Y))

seed = randint(0, 1000000)
print("Seed : " + str(seed))
xTrain, xTest, yTrain, yTest = train_test_split(X, Y, test_size=0.2, random_state=seed)

print("Train : " + str(xTrain))
print("Test : " + str(xTest))
print("Train Y : " + str(yTrain))
print("Test Y : " + str(yTest))

dcl = DecisionTreeClassifier(random_state=seed)
print("Training...")
dcl.fit(xTrain, yTrain)
print("Score : " + str(dcl.score(xTest, yTest)))
for i, x in enumerate(xTest):
    print("  " + str(x) + " -> " + str(dcl.predict([x])[0]) + " vs " + str(yTest[i]))
