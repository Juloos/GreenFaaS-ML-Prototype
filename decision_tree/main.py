from data import DATAS, SORTSCHEMA_DATAS, plot_domain

from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.tree import DecisionTreeClassifier, DecisionTreeRegressor
from sklearn.model_selection import train_test_split
from sklearn import tree
from random import randint
import matplotlib.pyplot as plt

SCHEMA, TEXT, WATTS, MS = range(4)

setseed = None  # Replace with your seed for reproducibility
fitsNumber = 1000  # Number of fits to do
n_estimators = 100  # Number of trees in the forest
step = 1  # classes are intervals of size <step> watts, not useful for regression (set to 1)

data = SORTSCHEMA_DATAS[0]
X = [(row[SCHEMA], row[TEXT]) for row in data]
Y = [int(row[WATTS] // step) for row in data]

# print("X : " + str(X))
# print("Y : " + str(Y))

def show_decitree_data(decitree, xTrain, xTest):
    predictions = decitree.predict(xTest)

    # Show the difference between predicted and real values
    fig = plt.figure()
    ax = fig.add_subplot(projection='3d')
    ax.set_xlabel("Schema")
    ax.set_ylabel("Text KB")
    ax.set_zlabel(("Watts Interval (%d)" % step) if step > 1 else "Watts")
    plot_domain(ax, [(row[SCHEMA], row[TEXT], int(row[WATTS] // step)) for row in data], "red")
    plot_domain(ax, [(*row, decitree.predict([row])[0]) for row in (xTrain)], "yellow")
    plot_domain(ax, [(*row, y) for row, y in zip(xTest, predictions)], "deepskyblue")
    plt.show()

    # Show the decision tree's parameters
    tree.plot_tree(decitree)
    plt.savefig("tree.png", dpi=500)

min_score, max_score = 1, 0
min_seed, max_seed = 0, 0
total_score = 0
for i in range(fitsNumber):
    seed = setseed or randint(0, 4294967295)
    xTrain, xTest, yTrain, yTest = train_test_split(X, Y, test_size=0.2, random_state=seed)
    decitree = RandomForestRegressor(random_state=seed, n_estimators=n_estimators)

    print("Training... (%d/%d)" % (i + 1, fitsNumber), end='\r')
    decitree.fit(xTrain, yTrain)
    if setseed is not None:
        print("Training done")
        show_decitree_data(decitree, xTrain, xTest)
        exit(0)

    score = decitree.score(xTest, yTest)
    # print("Score for seed %d : %.5f" % (seed, score))
    total_score += score
    if score < min_score:
        min_score = score
        min_seed = seed
    if score > max_score:
        max_score = score
        max_seed = seed

print("Min score : %.5f with seed %d" % (min_score, min_seed))
print("Max score : %.5f with seed %d" % (max_score, max_seed))
print("Average score : %.5f" % (total_score / fitsNumber))

# for i, x in enumerate(xTest):
#     print("  " + str(x) + " -> " + str(decitree.predict([x])[0]) + " vs " + str(yTest[i]))
