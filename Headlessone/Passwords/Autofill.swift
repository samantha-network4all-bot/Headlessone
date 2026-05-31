import Foundation

enum Autofill {
    static func jsFor(origin: String, username: String, password: String) -> String {
        let escapedUsername = username.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "\\n")
        let escapedPassword = password.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "\\n")
        return """
        (function() {
            var filled = false;
            var allInputs = document.querySelectorAll('input');
            var userField = null;
            var passField = null;
            for (var i = 0; i < allInputs.length; i++) {
                var inp = allInputs[i];
                var name = (inp.name || '').toLowerCase();
                var type = (inp.type || '').toLowerCase();
                if (name === 'password' || type === 'password') {
                    if (!passField) passField = inp;
                } else if (name === 'username' || name === 'email' || name === 'login' || type === 'email' || type === 'text' || type === '') {
                    if (!userField) userField = inp;
                }
            }
            if (userField) {
                userField.value = '\(escapedUsername)';
                userField.dispatchEvent(new Event('input', {bubbles: true}));
            }
            if (passField) {
                passField.value = '\(escapedPassword)';
                passField.dispatchEvent(new Event('input', {bubbles: true}));
            }
            return !!(userField || passField);
        })();
        """
    }
}
