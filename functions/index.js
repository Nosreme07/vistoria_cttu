const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.resetarSenha = functions.https.onCall(async (data, context) => {
  // Truque: dependendo da versão, o Firebase embrulha os dados dentro de outro "data"
  const payload = data.data ? data.data : data;

  // Isso vai escrever nos logs do Firebase exatamente o que o aplicativo mandou
  console.log("DADOS RECEBIDOS:", JSON.stringify(payload));

  // Verifica a chave usando o payload corrigido
  if (payload.segredo !== "CTTU@Admin2024") {
    throw new functions.https.HttpsError(
      'permission-denied', 
      `Acesso negado. O que chegou no servidor foi: ${JSON.stringify(payload)}`
    );
  }

  const uidUsuario = payload.uid;
  const novaSenha = payload.senha;

  if (!uidUsuario || !novaSenha) {
    throw new functions.https.HttpsError('invalid-argument', 'Faltam dados (UID ou Senha).');
  }

  try {
    // Altera a senha no Firebase Auth
    await admin.auth().updateUser(uidUsuario, {
      password: novaSenha
    });
    
    return { sucesso: true, mensagem: 'Senha alterada com sucesso no servidor!' };
  } catch (error) {
    console.error("Erro ao alterar senha:", error);
    throw new functions.https.HttpsError('internal', 'Erro do Firebase ao mudar senha: ' + error.message);
  }
});