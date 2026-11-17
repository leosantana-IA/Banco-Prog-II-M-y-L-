-- ============================================================================
-- SCRIPT DE CREACIÓN DE BASE DE DATOS Y DATOS DE PRUEBA: SISTEMA BANCARIO
-- ============================================================================

DROP DATABASE IF EXISTS banco;
CREATE DATABASE banco CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE banco;

-- ----------------------------------------------------------------------------
-- 1. ESTRUCTURA DE TABLAS, LLAVES Y RESTRICCIONES
-- ----------------------------------------------------------------------------

-- 👤 Tabla: usuarios
CREATE TABLE usuarios (
  id_usuario INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  apellidos VARCHAR(100) NOT NULL,
  usuario VARCHAR(50) NOT NULL UNIQUE,
  contrasena VARCHAR(255) NOT NULL,
  rol ENUM('CLIENTE','ADMIN') NOT NULL DEFAULT 'CLIENTE',
  estado_cuenta ENUM('ACTIVO','INACTIVO','BLOQUEADO') NOT NULL DEFAULT 'ACTIVO',
  correo VARCHAR(100) NOT NULL UNIQUE,
  telefono VARCHAR(15),
  fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  cambio_clave BOOLEAN NOT NULL DEFAULT TRUE,
  intentos_fallidos INT NOT NULL DEFAULT 0,
  bloqueado_hasta DATETIME NULL,
  CONSTRAINT chk_intentos_fallidos CHECK (intentos_fallidos >= 0)
) ENGINE=InnoDB;

-- 💳 Tabla: cuentas
CREATE TABLE cuentas (
  id_cuenta INT AUTO_INCREMENT PRIMARY KEY,
  numero_cuenta VARCHAR(20) NOT NULL UNIQUE,
  id_usuario INT NOT NULL,
  tipo_cuenta ENUM('AHORROS','CORRIENTE') NOT NULL DEFAULT 'AHORROS',
  saldo BIGINT NOT NULL DEFAULT 0,
  estado ENUM('ACTIVO','INACTIVO','BLOQUEADO') NOT NULL DEFAULT 'ACTIVO',
  fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_saldo CHECK (saldo >= 0),
  CONSTRAINT fk_cuentas_usuario FOREIGN KEY (id_usuario) 
    REFERENCES usuarios(id_usuario) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 🔁 Tabla: transferencias
CREATE TABLE transferencias (
  id_transferencia INT AUTO_INCREMENT PRIMARY KEY,
  id_cuenta_origen INT NOT NULL,
  id_cuenta_destino INT NOT NULL,
  valor BIGINT NOT NULL,
  descripcion VARCHAR(150),
  fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_valor_transferencia CHECK (valor > 0),
  CONSTRAINT chk_cuentas_distintas CHECK (id_cuenta_origen <> id_cuenta_destino),
  CONSTRAINT fk_transferencias_origen FOREIGN KEY (id_cuenta_origen) 
    REFERENCES cuentas(id_cuenta) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_transferencias_destino FOREIGN KEY (id_cuenta_destino) 
    REFERENCES cuentas(id_cuenta) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- 📒 Tabla: movimientos
CREATE TABLE movimientos (
  id_movimiento INT AUTO_INCREMENT PRIMARY KEY,
  id_cuenta INT NOT NULL,
  id_transferencia INT NULL,
  fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  tipo ENUM('CONSIGNACION','RETIRO','TRANSFERENCIA_ENVIADA','TRANSFERENCIA_RECIBIDA') NOT NULL,
  descripcion VARCHAR(150),
  valor BIGINT NOT NULL,
  saldo_resultante BIGINT NOT NULL,
  CONSTRAINT chk_valor_movimiento CHECK (valor <> 0),
  CONSTRAINT chk_saldo_resultante CHECK (saldo_resultante >= 0),
  CONSTRAINT fk_movimientos_cuenta FOREIGN KEY (id_cuenta) 
    REFERENCES cuentas(id_cuenta) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_movimientos_transferencia FOREIGN KEY (id_transferencia) 
    REFERENCES transferencias(id_transferencia) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Índices para optimizar consultas frecuentes
CREATE INDEX idx_movimientos_cuenta_fecha ON movimientos(id_cuenta, fecha);
CREATE INDEX idx_transferencias_fecha ON transferencias(fecha);

-- ----------------------------------------------------------------------------
-- 2. DATOS BÁSICOS DE PRUEBA (Consistentes en saldos y movimientos)
-- ----------------------------------------------------------------------------

-- Insertar Usuarios (Contraseñas simuladas con hash bcrypt de ejemplo)
INSERT INTO usuarios (nombre, apellidos, usuario, contrasena, rol, estado_cuenta, correo, telefono, cambio_clave) VALUES
('Carlos', 'Mendoza Ruiz', 'admin_banco', '$2b$12$eImiTXuWVxfM37uY4JANjQ==', 'ADMIN', 'ACTIVO', 'admin@banco.com', '3001112233', FALSE),
('Laura', 'Gómez Pérez', 'laura.gomez', '$2b$12$K9s8d7f6g5h4j3k2l1z0x9==', 'CLIENTE', 'ACTIVO', 'laura.gomez@email.com', '3104445566', FALSE),
('Andrés', 'Ramírez Soto', 'andres.ramirez', '$2b$12$P0o9i8u7y6t5r4e3w2q1a0==', 'CLIENTE', 'ACTIVO', 'andres.ramirez@email.com', '3207778899', TRUE),
('Sofía', 'Castro López', 'sofia.castro', '$2b$12$M1n2b3v4c5x6z7l8k9j0h1==', 'CLIENTE', 'BLOQUEADO', 'sofia.castro@email.com', '3159990011', FALSE);

-- Insertar Cuentas Bancarias (Saldos finales reflejan el historial de abajo)
INSERT INTO cuentas (numero_cuenta, id_usuario, tipo_cuenta, saldo, estado) VALUES
('1001000001', 2, 'AHORROS', 1200000, 'ACTIVO'),   -- Cuenta de Laura (id_cuenta = 1)
('1001000002', 2, 'CORRIENTE', 500000, 'ACTIVO'),  -- Segunda cuenta de Laura (id_cuenta = 2)
('1001000003', 3, 'AHORROS', 1100000, 'ACTIVO'),   -- Cuenta de Andrés (id_cuenta = 3)
('1001000004', 4, 'AHORROS', 250000, 'BLOQUEADO'); -- Cuenta de Sofía (id_cuenta = 4)

-- Insertar Consignaciones y Retiros Iniciales
INSERT INTO movimientos (id_cuenta, id_transferencia, tipo, descripcion, valor, saldo_resultante) VALUES
(1, NULL, 'CONSIGNACION', 'Depósito inicial apertura de cuenta', 1500000, 1500000),
(2, NULL, 'CONSIGNACION', 'Depósito inicial cuenta corriente', 500000, 500000),
(3, NULL, 'CONSIGNACION', 'Depósito inicial apertura de cuenta', 1000000, 1000000),
(4, NULL, 'CONSIGNACION', 'Depósito inicial apertura de cuenta', 250000, 250000),
(1, NULL, 'RETIRO', 'Retiro en cajero automático', -100000, 1400000);

-- Insertar Transferencia de Prueba (Laura envía $200.000 desde su cuenta 1 a Andrés cuenta 3)
INSERT INTO transferencias (id_cuenta_origen, id_cuenta_destino, valor, descripcion) VALUES
(1, 3, 200000, 'Pago de arriendo mensual');

-- Registrar los dos movimientos asociados a la transferencia (id_transferencia = 1)
INSERT INTO movimientos (id_cuenta, id_transferencia, tipo, descripcion, valor, saldo_resultante) VALUES
(1, 1, 'TRANSFERENCIA_ENVIADA', 'Transferencia a cuenta 1001000003 - Pago de arriendo mensual', -200000, 1200000),
(3, 1, 'TRANSFERENCIA_RECIBIDA', 'Transferencia desde cuenta 1001000001 - Pago de arriendo mensual', 200000, 1200000);

-- Insertar un retiro adicional de Andrés para cuadrar su saldo final en 1.100.000
INSERT INTO movimientos (id_cuenta, id_transferencia, tipo, descripcion, valor, saldo_resultante) VALUES
(3, NULL, 'RETIRO', 'Compra en datáfono', -100000, 1100000);
