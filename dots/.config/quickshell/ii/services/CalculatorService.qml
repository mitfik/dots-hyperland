pragma Singleton
pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string expression: ""
    property string result: ""
    property string errorMsg: ""
    property var history: Persistent.states.calculator.history

    function appendToExpression(str) {
        root.errorMsg = "";
        root.expression += str;
    }

    function clearExpression() {
        root.expression = "";
        root.result = "";
        root.errorMsg = "";
    }

    function backspace() {
        root.errorMsg = "";
        root.expression = root.expression.slice(0, -1);
    }

    function evaluate() {
        if (root.expression.trim() === "") return;

        let expr = root.expression;

        let processed = expr
            .replace(/×/g, '*')
            .replace(/÷/g, '/')
            .replace(/−/g, '-')
            .replace(/\^/g, '**')
            .replace(/%/g, '/100');

        try {
            let fn = new Function('return (' + processed + ')');
            let value = fn();

            if (typeof value !== 'number' || !isFinite(value)) {
                root.errorMsg = Translation.tr("Invalid expression");
                root.result = "";
                return;
            }

            let displayResult;
            if (Number.isInteger(value)) {
                displayResult = value.toString();
            } else {
                displayResult = parseFloat(value.toPrecision(12)).toString();
            }

            root.result = displayResult;
            root.errorMsg = "";

            let entry = {
                "expression": expr,
                "result": displayResult,
                "timestamp": Date.now()
            };

            let h = Persistent.states.calculator.history.slice();
            h.push(entry);
            if (h.length > 100) h = h.slice(h.length - 100);
            Persistent.states.calculator.history = h;

        } catch (e) {
            root.errorMsg = Translation.tr("Error");
            root.result = "";
        }
    }

    function useHistoryResult(resultStr) {
        let expr = root.expression.trim();
        let lastChar = expr.length > 0 ? expr[expr.length - 1] : "";
        let isOperator = "+-×÷−^(".indexOf(lastChar) >= 0;
        if (expr.length > 0 && !isOperator) {
            root.expression = resultStr;
        } else {
            root.expression = expr + resultStr;
        }
        root.errorMsg = "";
    }

    function appendOperatorWithHistoryResult(operator, resultStr) {
        root.expression = resultStr + operator;
        root.errorMsg = "";
    }

    function clearHistory() {
        Persistent.states.calculator.history = [];
    }
}
