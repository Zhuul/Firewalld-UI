/** @format */

'use strict';

// Boot 1, Shutdown 2, Boot and add to blacklist 3, Create new project 4, Add to blacklist 5, Remove from blacklist 6, Delete log 7, Add rule 8
const path = require('path');
const { systemTypes } = require(path.join(__dirname, '../extend/variable.js'));
const types = new Map(systemTypes);

module.exports = app => {
  const { DataTypes } = app.Sequelize;
  const System = app.model.define(
    'system',
    {
      id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true,
      },
      ip: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      user: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      time: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      type: {
        type: DataTypes.NUMBER,
        allowNull: false,
      },
      typeText: {
        type: DataTypes.VIRTUAL,
        get() {
          return types.get(this.type);
        },
        set(value) {
          throw new Error('Do not try to set the value of `unblockedText`!');
        },
      },
      details: {
        type: DataTypes.STRING,
        allowNull: false,
      },
    },
    {
      // MySQL database table name
      tableName: 'systems',
      // Do not use created_at, updated_at
      timestamps: false,
    }
  );

  return System;
};

// const Op = Sequelize.Op

// [Op.and]: {a: 5}           // AND (a = 5)
// [Op.or]: [{a: 5}, {a: 6}]  // (a = 5 OR a = 6)
// [Op.gt]: 6,                // id > 6
// [Op.gte]: 6,               // id >= 6
// [Op.lt]: 10,               // id < 10
// [Op.lte]: 10,              // id <= 10
// [Op.ne]: 20,               // id != 20
// [Op.eq]: 3,                // = 3
// [Op.not]: true,            // NOT TRUE
// [Op.between]: [6, 10],     // BETWEEN 6 AND 10
// [Op.notBetween]: [11, 15], // NOT BETWEEN 11 AND 15
// [Op.in]: [1, 2],           // IN [1, 2]
// [Op.notIn]: [1, 2],        // NOT IN [1, 2]
// [Op.like]: '%hat',         // LIKE '%hat'
// [Op.notLike]: '%hat'       // NOT LIKE '%hat'
// [Op.iLike]: '%hat'         // ILIKE '%hat' (case insensitive) (PG only)
// [Op.notILike]: '%hat'      // NOT ILIKE '%hat' (PG only)
// [Op.regexp]: '^[h|a|t]'    // REGEXP '^[h|a|t]' (MySQL/PG only)
// [Op.notRegexp]: '^[h|a|t]' // NOT REGEXP '^[h|a|t]' (MySQL/PG only)
// [Op.iRegexp]: '^[h|a|t]'    // ~* '^[h|a|t]' (PG only)
// [Op.notIRegexp]: '^[h|a|t]' // !~* '^[h|a|t]' (PG only)
// [Op.like]: { [Op.any]: ['cat', 'hat']} // LIKE ANY ARRAY['cat', 'hat'] - also works for iLike and notLike
// [Op.overlap]: [1, 2]       // && [1, 2] (PG array overlap operator)
// [Op.contains]: [1, 2]      // @> [1, 2] (PG array contains operator)
// [Op.contained]: [1, 2]     // <@ [1, 2] (PG array contained by operator)
// [Op.any]: [2,3]            // ANY ARRAY[2, 3]::INTEGER (PG only)
// [Op.col]: 'user.organization_id' // = 'user'.'organization_id', using database language-specific column identifiers, example using PG
