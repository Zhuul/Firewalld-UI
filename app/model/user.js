/** @format */

'use strict';
// const stringRandom = require('string-random');
const crypto = require('crypto');
module.exports = (app, sequelize) => {
  const { DataTypes } = app.Sequelize;

  const User = app.model.define(
    'user',
    {
      id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true,
      },
      username: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      password: {
        type: DataTypes.STRING,
        allowNull: false,
        // get() {
        //   return crypto.createHash('md5').update(this.getDataValue('password')).digest('hex');
        // },
        set(value) {
          this.setDataValue('password', app.setSalt(value));
        },
      },
      secret: {
        type: DataTypes.STRING,
        allowNull: true,
      },
      config: {
        type: DataTypes.JSON,
        allowNull: true,
      },
    },
    {
      // MySQL database table name
      tableName: 'users',
      // Do not use created_at, updated_at
      timestamps: false,
      defaultScope: {
        // dataValues: {
        //   // Exclude password, do not return password
        //   exclude: ['password'],
        // },
        // attributes: {
        //   // Exclude password, do not return password
        //   exclude: ['password'],
        // },
      },
    }
  );
  return User;
};
