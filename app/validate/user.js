/** @format */

module.exports = app => {
  let { validator } = app;
  // Validate if the username is correct
  validator.addRule('username', (rule, value) => {
    if (/^\d+$/.test(value)) return 'Username must be a string, not just numbers.';
    if (value.length < 4 || value.length > 10) return 'Username length should be between 4-10 characters';
  });
  // Add custom parameter validation rules
  validator.addRule('password', (rule, value) => {
    const pass = !/^\S*(?=\S{8,})(?=\S*\d)(?=\S*[A-Z])(?=\S*[a-z])(?=\S*[!@#$%^&*? ])\S*$/.test(value);
    if (pass) return 'Password must be at least 8 characters long and include at least one uppercase letter, one lowercase letter, one number, and one special character (!@#$%^&*?).';
  });

  validator.addRule('getbool', (rule, value) => {
    const pass = value == '' || value == 0 || value == '0' || value == null || value == 'null' ? false : true;
    return pass;
  });
};
