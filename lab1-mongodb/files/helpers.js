// Общие функции для шагов части 2. Подключаются через load().
// Печатают по одной короткой строке на действие: эти строки видно в выводе Ansible.

function showRole(name) {
  const r = db.getRole(name, { showPrivileges: true });
  if (!r) return print(`role ${name}: none`);
  const privs = r.privileges.map(p =>
    `${p.resource.db}.${p.resource.collection || '*'} [${p.actions.join(', ')}]`);
  print(`role ${name}: ${privs.join('; ')}`);
}

function showUser(name) {
  const u = db.getUser(name);
  if (!u) return print(`user ${name}: none`);
  print(`user ${name}: roles [${u.roles.map(r => r.role).join(', ')}]`);
}

// Создать роль или вернуть ей исходный набор прав.
function ensureRole(name, privileges) {
  if (db.getRole(name)) {
    db.updateRole(name, { privileges, roles: [] });
    print(`role ${name}: exists, privileges reset`);
  } else {
    db.createRole({ role: name, privileges, roles: [] });
    print(`role ${name}: created`);
  }
}

function hasRole(user, role) {
  return db.getUser(user).roles.some(r => r.role === role);
}

function grant(user, role) {
  if (hasRole(user, role)) return print(`${user}: already has ${role}`);
  db.grantRolesToUser(user, [role]);
  print(`${user}: granted ${role}`);
}

function revoke(user, role) {
  if (!hasRole(user, role)) return print(`${user}: has no ${role}`);
  db.revokeRolesFromUser(user, [role]);
  print(`${user}: revoked ${role}`);
}
