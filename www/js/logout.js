// Logout fetch request function with customizable endpoint
function logout(endpoint) {
  fetch(`/${endpoint}`, {
    method: 'GET'  // Change to GET instead of POST
  })
  .then(response => {
      if (!response.ok) {
          throw new Error('Network response was not ok');
      }
      return response.json();
  })
  .catch(error => {
      console.error('There was a problem with the fetch operation:', error);
  });
}
