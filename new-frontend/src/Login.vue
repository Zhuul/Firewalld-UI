<template>
  <div class="login-container">
    <el-card class="login-card">
      <div class="title">
        <h2>Firewalld UI</h2>
      </div>
      <el-form :model="loginForm" :rules="rules" ref="loginForm" @submit.native.prevent>
        <el-form-item prop="username">
          <el-input 
            v-model="loginForm.username" 
            placeholder="Username"
            prefix-icon="el-icon-user">
          </el-input>
        </el-form-item>
        <el-form-item prop="password">
          <el-input 
            v-model="loginForm.password" 
            placeholder="Password" 
            prefix-icon="el-icon-lock"
            show-password
            type="password">
          </el-input>
        </el-form-item>
        <el-form-item>
          <el-checkbox v-model="loginForm.rememberMe">Remember me</el-checkbox>
        </el-form-item>
        <el-form-item>
          <el-button 
            type="primary" 
            :loading="loading" 
            class="login-button" 
            @click="handleLogin">
            Login
          </el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script>
export default {
  name: 'Login',
  data() {
    return {
      loginForm: {
        username: '',
        password: '',
        rememberMe: false
      },
      loading: false,
      rules: {
        username: [
          { required: true, message: 'Please enter username', trigger: 'blur' }
        ],
        password: [
          { required: true, message: 'Please enter password', trigger: 'blur' }
        ]
      }
    };
  },
  methods: {
    handleLogin() {
      this.$refs.loginForm.validate(valid => {
        if (valid) {
          this.loading = true;
          
          // Call the login API
          fetch('/login', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({
              username: this.loginForm.username,
              password: this.loginForm.password
            })
          })
          .then(response => response.json())
          .then(data => {
            this.loading = false;
            
            if (data.success) {
              // Save token to localStorage or cookies if remember me is checked
              if (this.loginForm.rememberMe) {
                localStorage.setItem('token', data.data.token);
              } else {
                sessionStorage.setItem('token', data.data.token);
              }
              
              // Redirect to dashboard
              window.location.href = '/';
            } else {
              this.$message.error(data.message || 'Login failed');
            }
          })
          .catch(error => {
            this.loading = false;
            this.$message.error('Network error: ' + error.message);
            console.error('Login error:', error);
          });
        }
      });
    }
  }
};
</script>

<style scoped>
.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100vh;
  background-color: #f5f7fa;
}

.login-card {
  width: 350px;
  border-radius: 8px;
}

.title {
  text-align: center;
  margin-bottom: 20px;
}

.login-button {
  width: 100%;
}
</style>